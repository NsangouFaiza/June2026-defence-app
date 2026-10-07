from django.db import transaction
from django.db.models import Sum, Count, Q
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model

from .models import AuditLog
from .serializers import AuditLogSerializer

User = get_user_model()

VALID_ROLES = [choice[0] for choice in User._meta.get_field('role').choices]


class IsSystemAdmin(permissions.BasePermission):
    """Allows access to Django staff/superusers and the admin roles allowed into the app's admin panel."""

    ADMIN_ROLES = ('system_admin', 'blood_bank_admin')

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user and user.is_authenticated and
            (user.is_staff or user.is_superuser or getattr(user, 'role', '') in self.ADMIN_ROLES)
        )


def log_admin_action(request, action_type, model_name, object_id, description, changes=None):
    try:
        AuditLog.objects.create(
            user=request.user,
            action=action_type,
            model_name=model_name,
            object_id=str(object_id),
            description=description,
            ip_address=request.META.get('REMOTE_ADDR'),
            user_agent=request.META.get('HTTP_USER_AGENT', ''),
            changes=changes or {},
        )
    except Exception:
        pass


class AuditLogListView(generics.ListAPIView):
    serializer_class = AuditLogSerializer
    permission_classes = [IsSystemAdmin]
    filterset_fields = ['user', 'action', 'model_name']

    def get_queryset(self):
        return AuditLog.objects.select_related('user').all()


def serialize_admin_user(u):
    staff = getattr(u, 'hospital_staff', None)
    return {
        'id': u.id,
        'email': u.email,
        'full_name': u.full_name,
        'phone_number': u.phone_number,
        'gender': u.gender,
        'blood_group': u.blood_group,
        'city': u.city,
        'region': u.region,
        'address': u.address,
        'role': u.role,
        'is_active': u.is_active,
        'is_verified': u.is_verified,
        'is_staff': u.is_staff,
        'date_joined': u.date_joined,
        'last_login': u.last_login,
        'profile_picture': u.profile_picture.url if u.profile_picture else None,
        'hospital_id': staff.hospital_id if staff else None,
        'hospital_name': staff.hospital.name if staff else None,
    }


class AdminUserViewSet(viewsets.ViewSet):
    """Admin management of all platform users."""

    permission_classes = [IsSystemAdmin]
    EDITABLE_FIELDS = ['full_name', 'phone_number', 'gender', 'blood_group', 'city', 'region', 'address', 'is_verified']

    def _get_user(self, pk):
        try:
            return User.objects.select_related('hospital_staff__hospital').get(pk=pk)
        except (User.DoesNotExist, ValueError):
            return None

    def _not_found(self):
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)

    def list(self, request):
        """List users. Supports ?search=, ?role=, ?is_active=true|false."""
        users = User.objects.select_related('hospital_staff__hospital').order_by('-date_joined')

        search = request.query_params.get('search', '').strip()
        if search:
            users = users.filter(
                Q(full_name__icontains=search) | Q(email__icontains=search) |
                Q(phone_number__icontains=search) | Q(city__icontains=search)
            )
        role = request.query_params.get('role')
        if role:
            users = users.filter(role=role)
        is_active = request.query_params.get('is_active')
        if is_active in ('true', 'false'):
            users = users.filter(is_active=(is_active == 'true'))

        return Response([serialize_admin_user(u) for u in users])

    def retrieve(self, request, pk=None):
        """Full user profile with role-specific details and recent activity."""
        from donations.models import Donation
        from requests.models import BloodRequest
        from appointments.models import Appointment
        from payments.models import Payment

        user = self._get_user(pk)
        if not user:
            return self._not_found()

        data = serialize_admin_user(user)
        data.update({
            'date_of_birth': user.date_of_birth,
            'age': user.age,
            'language': user.language,
            'two_factor_enabled': user.two_factor_enabled,
            'is_superuser': user.is_superuser,
            'hospital_position': user.hospital_staff.position if getattr(user, 'hospital_staff', None) else None,
            'donor_profile': None,
            'patient_profile': None,
            'recent_donations': [],
            'recent_appointments': [],
            'recent_requests': [],
        })

        donor = getattr(user, 'donor_profile', None)
        if donor:
            data['donor_profile'] = {
                'total_donations': donor.total_donations,
                'total_blood_units': donor.total_blood_units,
                'lives_saved': donor.lives_saved,
                'points': donor.points,
                'level': donor.level,
                'is_eligible': donor.is_eligible,
                'is_available': donor.is_available,
                'eligibility_status': donor.eligibility_status,
                'last_donation_date': donor.last_donation_date,
                'next_eligible_date': donor.next_eligible_date,
                'weight': donor.weight,
                'height': donor.height,
            }
            data['recent_donations'] = [
                {
                    'id': d.id,
                    'hospital_name': d.hospital.name if d.hospital_id else None,
                    'blood_group': d.blood_group,
                    'quantity_ml': d.quantity_ml,
                    'status': d.status,
                    'created_at': d.created_at,
                }
                for d in Donation.objects.filter(donor=donor).select_related('hospital').order_by('-created_at')[:10]
            ]
            data['recent_appointments'] = [
                {
                    'id': a.id,
                    'hospital_name': a.hospital.name if a.hospital_id else None,
                    'scheduled_date': a.scheduled_date,
                    'scheduled_time': a.scheduled_time,
                    'status': a.status,
                }
                for a in Appointment.objects.filter(donor=donor).select_related('hospital').order_by('-scheduled_date')[:10]
            ]

        patient = getattr(user, 'patient_profile', None)
        if patient:
            data['patient_profile'] = {
                'emergency_contact_name': patient.emergency_contact_name,
                'emergency_contact_phone': patient.emergency_contact_phone,
                'medical_conditions': patient.medical_conditions,
                'current_medications': patient.current_medications,
                'allergies': patient.allergies,
                'weight': patient.weight,
                'height': patient.height,
            }
            data['recent_requests'] = [
                {
                    'id': r.id,
                    'hospital_name': r.hospital.name if r.hospital_id else None,
                    'blood_group': r.blood_group,
                    'quantity': r.quantity,
                    'urgency': r.urgency,
                    'status': r.status,
                    'is_emergency': r.is_emergency,
                    'created_at': r.created_at,
                }
                for r in BloodRequest.objects.filter(patient=patient).select_related('hospital').order_by('-created_at')[:10]
            ]

        payments = Payment.objects.filter(user=user).order_by('-created_at')
        data['payments_total'] = float(payments.filter(status='SUCCESS').aggregate(t=Sum('amount'))['t'] or 0)
        data['recent_payments'] = [
            {
                'id': p.id,
                'payment_type': p.get_payment_type_display(),
                'amount': float(p.amount),
                'status': p.status,
                'payment_method': p.payment_method,
                'created_at': p.created_at,
            }
            for p in payments[:10]
        ]
        data['recent_logins'] = [
            {'device_name': l.device_name, 'ip_address': l.ip_address, 'login_time': l.login_time, 'status': l.status}
            for l in user.login_history.order_by('-login_time')[:5]
        ]
        return Response(data)

    def create(self, request):
        """Create a user account (any role). Optionally attach hospital staff to a hospital."""
        from hospitals.models import Hospital, HospitalStaff

        email = (request.data.get('email') or '').strip().lower()
        password = request.data.get('password') or ''
        full_name = (request.data.get('full_name') or '').strip()
        phone_number = (request.data.get('phone_number') or '').strip()
        role = request.data.get('role') or 'donor'
        hospital_id = request.data.get('hospital_id')

        errors = {}
        if not email:
            errors['email'] = 'Email is required.'
        elif User.objects.filter(email__iexact=email).exists():
            errors['email'] = 'A user with this email already exists.'
        if len(password) < 6:
            errors['password'] = 'Password must be at least 6 characters.'
        if not full_name:
            errors['full_name'] = 'Full name is required.'
        if not phone_number:
            errors['phone_number'] = 'Phone number is required.'
        if role not in VALID_ROLES:
            errors['role'] = f'Invalid role. Choose one of: {", ".join(VALID_ROLES)}.'
        hospital = None
        if hospital_id:
            hospital = Hospital.objects.filter(pk=hospital_id).first()
            if not hospital:
                errors['hospital_id'] = 'Hospital not found.'
        if errors:
            return Response({'error': next(iter(errors.values())), 'errors': errors}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            user = User.objects.create_user(
                email=email,
                password=password,
                full_name=full_name,
                phone_number=phone_number,
                role=role,
                city=request.data.get('city') or None,
                region=request.data.get('region') or None,
                is_verified=True,
                is_staff=(role == 'system_admin'),
            )
            if hospital and role == 'hospital_staff':
                HospitalStaff.objects.create(user=user, hospital=hospital, position=request.data.get('position') or None)

        log_admin_action(request, 'CREATE', 'User', user.id, f'Admin created user {user.email} ({role})')
        user = self._get_user(user.id)
        return Response(serialize_admin_user(user), status=status.HTTP_201_CREATED)

    def partial_update(self, request, pk=None):
        """Edit profile fields and/or change role."""
        user = self._get_user(pk)
        if not user:
            return self._not_found()

        changes = {}
        for field in self.EDITABLE_FIELDS:
            if field in request.data:
                old = getattr(user, field)
                setattr(user, field, request.data.get(field))
                changes[field] = [str(old), str(request.data.get(field))]

        new_role = request.data.get('role')
        if new_role and new_role != user.role:
            if new_role not in VALID_ROLES:
                return Response({'error': 'Invalid role'}, status=status.HTTP_400_BAD_REQUEST)
            if user.pk == request.user.pk:
                return Response({'error': 'You cannot change your own role.'}, status=status.HTTP_400_BAD_REQUEST)
            changes['role'] = [user.role, new_role]
            user.role = new_role
            user.is_staff = new_role == 'system_admin' or user.is_superuser
            # Make sure role-specific profiles exist
            if new_role == 'donor':
                from donors.models import Donor
                Donor.objects.get_or_create(user=user)
            elif new_role == 'patient':
                from patients.models import Patient
                Patient.objects.get_or_create(user=user)

        user.save()
        log_admin_action(request, 'UPDATE', 'User', user.id, f'Admin updated user {user.email}', changes)
        return Response(serialize_admin_user(self._get_user(user.id)))

    def update(self, request, pk=None):
        return self.partial_update(request, pk)

    def destroy(self, request, pk=None):
        user = self._get_user(pk)
        if not user:
            return self._not_found()
        if user.pk == request.user.pk:
            return Response({'error': 'You cannot delete your own account.'}, status=status.HTTP_400_BAD_REQUEST)
        if user.is_superuser and not request.user.is_superuser:
            return Response({'error': 'Only a superuser can delete a superuser.'}, status=status.HTTP_403_FORBIDDEN)
        email = user.email
        user.delete()
        log_admin_action(request, 'DELETE', 'User', pk, f'Admin deleted user {email}')
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        user = self._get_user(pk)
        if not user:
            return self._not_found()
        if user.pk == request.user.pk:
            return Response({'error': 'You cannot suspend your own account.'}, status=status.HTTP_400_BAD_REQUEST)
        user.is_active = False
        user.save(update_fields=['is_active'])
        log_admin_action(request, 'UPDATE', 'User', user.id, f'Admin suspended user {user.email}')
        return Response({'message': f'User {user.email} suspended', 'user': serialize_admin_user(user)})

    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        user = self._get_user(pk)
        if not user:
            return self._not_found()
        user.is_active = True
        user.save(update_fields=['is_active'])
        log_admin_action(request, 'UPDATE', 'User', user.id, f'Admin activated user {user.email}')
        return Response({'message': f'User {user.email} activated', 'user': serialize_admin_user(user)})

    @action(detail=True, methods=['post'])
    def reset_password(self, request, pk=None):
        user = self._get_user(pk)
        if not user:
            return self._not_found()
        new_password = request.data.get('new_password') or ''
        if len(new_password) < 6:
            return Response({'error': 'Password must be at least 6 characters.'}, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(new_password)
        user.save(update_fields=['password'])
        log_admin_action(request, 'UPDATE', 'User', user.id, f'Admin reset password for {user.email}')
        return Response({'message': f'Password reset for {user.email}'})


class AdminHospitalViewSet(viewsets.ModelViewSet):
    """Admin management of hospitals (including inactive / expired ones) and their staff."""

    permission_classes = [IsSystemAdmin]

    def get_serializer_class(self):
        from hospitals.serializers import HospitalSerializer
        return HospitalSerializer

    def get_queryset(self):
        from hospitals.models import Hospital
        from django.utils import timezone

        qs = Hospital.objects.annotate(staff_count=Count('staff', distinct=True)).order_by('name')
        params = self.request.query_params

        search = params.get('search', '').strip()
        if search:
            qs = qs.filter(Q(name__icontains=search) | Q(city__icontains=search) | Q(region__icontains=search))
        region = params.get('region')
        if region:
            qs = qs.filter(region__iexact=region)

        sub = params.get('subscription')
        now = timezone.now()
        if sub == 'active':
            qs = qs.filter(is_active=True, subscription_end_date__gte=now).exclude(subscription_status='DEACTIVATED')
        elif sub == 'expired':
            qs = qs.filter(is_active=True).filter(
                Q(subscription_end_date__isnull=True) | Q(subscription_end_date__lt=now)
            ).exclude(subscription_status='DEACTIVATED')
        elif sub == 'deactivated':
            qs = qs.filter(Q(is_active=False) | Q(subscription_status='DEACTIVATED'))
        return qs

    def _with_extra(self, hospital):
        data = self.get_serializer(hospital).data
        data['staff_count'] = getattr(hospital, 'staff_count', None)
        if data['staff_count'] is None:
            data['staff_count'] = hospital.staff.count()
        return data

    def list(self, request, *args, **kwargs):
        return Response([self._with_extra(h) for h in self.get_queryset()])

    def retrieve(self, request, *args, **kwargs):
        hospital = self.get_object()
        data = self._with_extra(hospital)
        from inventory.models import BloodInventory
        from requests.models import BloodRequest
        data['total_blood_units'] = BloodInventory.objects.filter(hospital=hospital).aggregate(t=Sum('quantity'))['t'] or 0
        data['pending_requests'] = BloodRequest.objects.filter(hospital=hospital, status='PENDING').count()
        return Response(data)

    def perform_create(self, serializer):
        hospital = serializer.save()
        log_admin_action(self.request, 'CREATE', 'Hospital', hospital.id, f'Admin created hospital {hospital.name}')

    def perform_update(self, serializer):
        hospital = serializer.save()
        log_admin_action(self.request, 'UPDATE', 'Hospital', hospital.id, f'Admin updated hospital {hospital.name}')

    def perform_destroy(self, instance):
        log_admin_action(self.request, 'DELETE', 'Hospital', instance.id, f'Admin deleted hospital {instance.name}')
        instance.delete()

    @action(detail=True, methods=['get', 'post'])
    def staff(self, request, pk=None):
        """GET: list staff of a hospital. POST {user_id, position?, department?}: assign a user as staff."""
        from hospitals.models import HospitalStaff

        hospital = self.get_object()

        if request.method == 'POST':
            user_id = request.data.get('user_id')
            user = User.objects.filter(pk=user_id).first() if user_id else None
            if not user:
                return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
            with transaction.atomic():
                # A user can only belong to one hospital (OneToOne), so move them if already assigned.
                HospitalStaff.objects.filter(user=user).delete()
                HospitalStaff.objects.create(
                    user=user,
                    hospital=hospital,
                    position=request.data.get('position') or None,
                    department=request.data.get('department') or None,
                )
                if user.role not in ('hospital_staff', 'system_admin'):
                    user.role = 'hospital_staff'
                    user.save(update_fields=['role'])
            log_admin_action(request, 'UPDATE', 'Hospital', hospital.id, f'Assigned {user.email} to {hospital.name}')

        staff_qs = HospitalStaff.objects.filter(hospital=hospital).select_related('user')
        return Response([
            {
                'id': s.id,
                'user_id': s.user_id,
                'full_name': s.user.full_name,
                'email': s.user.email,
                'phone_number': s.user.phone_number,
                'position': s.position,
                'department': s.department,
                'is_active': s.is_active and s.user.is_active,
            }
            for s in staff_qs
        ])

    @action(detail=True, methods=['delete'], url_path=r'staff/(?P<staff_id>\d+)')
    def remove_staff(self, request, pk=None, staff_id=None):
        from hospitals.models import HospitalStaff

        hospital = self.get_object()
        deleted, _ = HospitalStaff.objects.filter(hospital=hospital, pk=staff_id).delete()
        if not deleted:
            return Response({'error': 'Staff member not found'}, status=status.HTTP_404_NOT_FOUND)
        log_admin_action(request, 'UPDATE', 'Hospital', hospital.id, f'Removed staff #{staff_id} from {hospital.name}')
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'])
    def extend_subscription(self, request, pk=None):
        """Manually grant subscription months (e.g. offline payment). Body: {months: int}."""
        hospital = self.get_object()
        try:
            months = int(request.data.get('months', 1))
        except (TypeError, ValueError):
            months = 0
        if months < 1 or months > 24:
            return Response({'error': 'Months must be between 1 and 24.'}, status=status.HTTP_400_BAD_REQUEST)
        hospital.extend_subscription(months=months)
        log_admin_action(request, 'UPDATE', 'Hospital', hospital.id, f'Granted {months} month(s) subscription to {hospital.name}')
        return Response(self._with_extra(hospital))


class AdminStatisticsView(APIView):
    permission_classes = [IsSystemAdmin]

    def get(self, request):
        from donors.models import Donor
        from patients.models import Patient
        from hospitals.models import Hospital
        from requests.models import BloodRequest
        from donations.models import Donation
        from inventory.models import BloodInventory
        from appointments.models import Appointment
        from campaigns.models import Campaign
        from payments.models import Payment

        successful_payments = Payment.objects.filter(status='SUCCESS')
        total_revenue = successful_payments.aggregate(total=Sum('amount'))['total'] or 0.0
        sub_revenue = successful_payments.filter(payment_type='HOSPITAL_SUBSCRIPTION').aggregate(total=Sum('amount'))['total'] or 0.0
        req_revenue = successful_payments.filter(payment_type='BLOOD_REQUEST_PAYMENT').aggregate(total=Sum('amount'))['total'] or 0.0
        pending_requests = BloodRequest.objects.filter(status='PENDING').count()

        stats = {
            'total_users': User.objects.count(),
            'active_users': User.objects.filter(is_active=True).count(),
            'total_donors': Donor.objects.count(),
            'total_patients': Patient.objects.count(),
            'total_hospitals': Hospital.objects.count(),
            'active_hospitals': len([h for h in Hospital.objects.all() if h.is_subscription_active]),
            'total_blood_requests': BloodRequest.objects.count(),
            'total_donations': Donation.objects.count(),
            'total_appointments': Appointment.objects.count(),
            'total_campaigns': Campaign.objects.count(),
            'pending_requests': pending_requests,
            'active_requests': pending_requests,
            'completed_donations': Donation.objects.filter(status='COMPLETED').count(),
            'total_blood_units': BloodInventory.objects.aggregate(total=Sum('quantity'))['total'] or 0,
            'total_revenue': float(total_revenue),
            'subscription_revenue': float(sub_revenue),
            'request_revenue': float(req_revenue),
        }
        stats.update(self._breakdowns(User, Donor, Hospital, BloodRequest, Donation, BloodInventory, Payment))
        return Response(stats)

    @staticmethod
    def _month_starts(count=6):
        from django.utils import timezone
        now = timezone.now()
        year, month = now.year, now.month
        starts = []
        for _ in range(count):
            starts.append((year, month))
            month -= 1
            if month == 0:
                year, month = year - 1, 12
        return list(reversed(starts))

    def _breakdowns(self, User, Donor, Hospital, BloodRequest, Donation, BloodInventory, Payment):
        from datetime import datetime
        from django.utils import timezone
        from django.db.models.functions import TruncMonth

        months = self._month_starts(6)
        first_year, first_month = months[0]
        since = timezone.make_aware(datetime(first_year, first_month, 1))

        def monthly(qs, date_field, value=None):
            rows = (
                qs.filter(**{f'{date_field}__gte': since})
                .annotate(m=TruncMonth(date_field))
                .values('m')
                .annotate(v=value or Count('id'))
            )
            by_month = {(r['m'].year, r['m'].month): r['v'] or 0 for r in rows if r['m']}
            return [float(by_month.get(ym, 0)) if value else int(by_month.get(ym, 0)) for ym in months]

        now = timezone.now()
        this_month_start = timezone.make_aware(datetime(now.year, now.month, 1))

        hospitals = list(Hospital.objects.all())
        hospital_status = {'active': 0, 'expired': 0, 'deactivated': 0}
        for h in hospitals:
            if not h.is_active or h.subscription_status == 'DEACTIVATED':
                hospital_status['deactivated'] += 1
            elif h.is_subscription_active:
                hospital_status['active'] += 1
            else:
                hospital_status['expired'] += 1

        stock = {
            r['blood_group']: r['t'] or 0
            for r in BloodInventory.objects.filter(status='available').values('blood_group').annotate(t=Sum('quantity'))
        }
        blood_groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']

        successful = Payment.objects.filter(status='SUCCESS')
        return {
            'months': [f'{y}-{m:02d}' for y, m in months],
            'monthly_new_users': monthly(User.objects.all(), 'date_joined'),
            'monthly_donations': monthly(Donation.objects.all(), 'created_at'),
            'monthly_requests': monthly(BloodRequest.objects.all(), 'created_at'),
            'monthly_revenue': monthly(successful, 'created_at', Sum('amount')),
            'new_users_this_month': User.objects.filter(date_joined__gte=this_month_start).count(),
            'donations_this_month': Donation.objects.filter(created_at__gte=this_month_start).count(),
            'users_by_role': {
                r['role']: r['c'] for r in User.objects.values('role').annotate(c=Count('id'))
            },
            'requests_by_status': {
                r['status']: r['c'] for r in BloodRequest.objects.values('status').annotate(c=Count('id'))
            },
            'emergency_requests': BloodRequest.objects.filter(is_emergency=True, status='PENDING').count(),
            'blood_stock': [{'blood_group': g, 'units': stock.get(g, 0)} for g in blood_groups],
            'hospital_status': hospital_status,
            'available_donors': Donor.objects.filter(is_available=True, is_eligible=True).count(),
            'top_hospitals': [
                {'name': r['hospital__name'], 'donations': r['c']}
                for r in Donation.objects.values('hospital__name').annotate(c=Count('id')).order_by('-c')[:5]
                if r['hospital__name']
            ],
        }
