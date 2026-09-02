from rest_framework import generics, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets

from .models import Campaign, CampaignRegistration
from .serializers import CampaignSerializer, CampaignRegistrationSerializer
import logging

logger = logging.getLogger(__name__)



class CampaignListCreateView(generics.ListCreateAPIView):
    serializer_class = CampaignSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    filterset_fields = ['status', 'campaign_type']

    def get_queryset(self):
        from .services import publish_scheduled_campaigns
        try:
            publish_scheduled_campaigns()
        except Exception as e:
            logger.error(f"Error publishing scheduled campaigns on list load: {e}")
        return Campaign.objects.all()


class CampaignDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CampaignSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        from .services import publish_scheduled_campaigns
        try:
            publish_scheduled_campaigns()
        except Exception as e:
            logger.error(f"Error publishing scheduled campaigns on detail load: {e}")
        return super().get_object()


    def perform_update(self, serializer):
        old_instance = self.get_object()
        old_title = old_instance.title
        old_start = old_instance.start_date
        old_location = old_instance.location
        old_status = old_instance.status
        
        instance = serializer.save()
        
        from notifications.models import Notification
        
        # If status was published and changed to cancelled, notify
        if old_status == 'PUBLISHED' and instance.status == 'CANCELLED':
            registrations = instance.registrations.exclude(status='CANCELLED')
            for reg in registrations:
                Notification.objects.create(
                    recipient=reg.donor.user,
                    notification_type='CAMPAIGN',
                    title=f"Campaign CANCELLED: {instance.title}",
                    message=f"We regret to inform you that the campaign '{instance.title}' has been cancelled.",
                    data={'campaign_id': instance.id, 'priority': 'Emergency'}
                )
        
        # If campaign is published, notify all registered donors of critical field updates
        elif instance.status == 'PUBLISHED':
            changed = []
            if old_title != instance.title:
                changed.append('title')
            if old_start != instance.start_date:
                changed.append('date')
            if old_location != instance.location:
                changed.append('location')
            
            if changed:
                registrations = instance.registrations.exclude(status='CANCELLED')
                for reg in registrations:
                    Notification.objects.create(
                        recipient=reg.donor.user,
                        notification_type='CAMPAIGN',
                        title=f"Campaign Updated: {instance.title}",
                        message=f"The campaign '{instance.title}' has been updated (modified fields: {', '.join(changed)}). Please review the updated details.",
                        data={'campaign_id': instance.id, 'priority': instance.priority}
                    )


class CampaignActionViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=True, methods=['post'])
    def register(self, request, pk=None):
        """Register current user (RSVP) for a campaign."""
        try:
            campaign = Campaign.objects.get(pk=pk)
            from donors.models import Donor
            donor = Donor.objects.get(user=request.user)
            
            reg, created = CampaignRegistration.objects.get_or_create(
                campaign=campaign,
                donor=donor,
            )
            reg.status = 'REGISTERED'
            reg.save()
            
            from notifications.models import Notification
            Notification.objects.create(
                recipient=request.user,
                notification_type='CAMPAIGN',
                title="Registration Confirmed!",
                message=f"You have registered successfully for the campaign '{campaign.title}'.",
                data={'campaign_id': campaign.id}
            )
            
            return Response({'message': 'Successfully registered for campaign', 'status': reg.status})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)
        except Donor.DoesNotExist:
            return Response({'error': 'Donor profile not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def unregister(self, request, pk=None):
        """Unregister current user (Cancel RSVP) from a campaign."""
        try:
            campaign = Campaign.objects.get(pk=pk)
            from donors.models import Donor
            donor = Donor.objects.get(user=request.user)
            
            try:
                reg = CampaignRegistration.objects.get(campaign=campaign, donor=donor)
                reg.status = 'CANCELLED'
                reg.save()
                return Response({'message': 'Successfully cancelled RSVP'})
            except CampaignRegistration.DoesNotExist:
                return Response({'message': 'No RSVP found to cancel'})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)
        except Donor.DoesNotExist:
            return Response({'error': 'Donor profile not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['get'])
    def my_campaigns(self, request):
        """Get campaigns current donor is registered for."""
        from donors.models import Donor
        try:
            donor = Donor.objects.get(user=request.user)
            registrations = CampaignRegistration.objects.filter(donor=donor).exclude(status='CANCELLED')
            campaigns = [r.campaign for r in registrations]
            serializer = CampaignSerializer(campaigns, many=True, context={'request': request})
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response([])

    @action(detail=True, methods=['get'])
    def target_donors(self, request, pk=None):
        """Evaluate campaign criteria and return matching eligible donors."""
        campaign = Campaign.objects.get(pk=pk)
        from donors.models import Donor
        from django.db.models import Q
        donors = Donor.objects.all()
        
        if campaign.target_blood_group:
            donors = donors.filter(user__blood_group__iexact=campaign.target_blood_group)
        if campaign.target_location:
            donors = donors.filter(Q(user__city__icontains=campaign.target_location) | Q(user__region__icontains=campaign.target_location))
        if campaign.target_eligibility == 'eligible':
            donors = donors.filter(is_eligible=True)
        elif campaign.target_eligibility == 'ineligible':
            donors = donors.filter(is_eligible=False)
            
        from datetime import date
        if campaign.target_age_min:
            max_dob = date(date.today().year - campaign.target_age_min, date.today().month, date.today().day)
            donors = donors.filter(user__date_of_birth__lte=max_dob)
        if campaign.target_age_max:
            min_dob = date(date.today().year - campaign.target_age_max - 1, date.today().month, date.today().day)
            donors = donors.filter(user__date_of_birth__gte=min_dob)
            
        from donors.serializers import DonorDetailSerializer
        serializer = DonorDetailSerializer(donors, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def send_campaign(self, request, pk=None):
        """Send notifications to targeted or custom-selected donor recipients."""
        campaign = Campaign.objects.get(pk=pk)
        recipient_ids = request.data.get('recipient_ids', [])
        
        from donors.models import Donor
        from notifications.models import Notification
        from django.db.models import Q
        
        if recipient_ids:
            donors = Donor.objects.filter(pk__in=recipient_ids)
        else:
            donors = Donor.objects.all()
            if campaign.target_blood_group:
                donors = donors.filter(user__blood_group__iexact=campaign.target_blood_group)
            if campaign.target_location:
                donors = donors.filter(Q(user__city__icontains=campaign.target_location) | Q(user__region__icontains=campaign.target_location))
            if campaign.target_eligibility == 'eligible':
                donors = donors.filter(is_eligible=True)
            elif campaign.target_eligibility == 'ineligible':
                donors = donors.filter(is_eligible=False)
            
            from datetime import date
            if campaign.target_age_min:
                max_dob = date(date.today().year - campaign.target_age_min, date.today().month, date.today().day)
                donors = donors.filter(user__date_of_birth__lte=max_dob)
            if campaign.target_age_max:
                min_dob = date(date.today().year - campaign.target_age_max - 1, date.today().month, date.today().day)
                donors = donors.filter(user__date_of_birth__gte=min_dob)

        for donor in donors:
            Notification.objects.create(
                recipient=donor.user,
                notification_type='CAMPAIGN',
                title=f"[{campaign.priority.upper()}] {campaign.title}",
                message=campaign.description,
                data={'campaign_id': campaign.id, 'priority': campaign.priority}
            )
            
        campaign.is_sent = True
        campaign.status = 'PUBLISHED'
        campaign.recipient_count = donors.count()
        campaign.save()
        
        return Response({
            'message': f'Campaign sent successfully to {campaign.recipient_count} recipients.',
            'recipient_count': campaign.recipient_count
        })

    @action(detail=True, methods=['post'])
    def duplicate(self, request, pk=None):
        """Duplicate a campaign draft."""
        try:
            campaign = Campaign.objects.get(pk=pk)
            campaign.pk = None
            campaign.title = f"{campaign.title} (Copy)"
            campaign.status = 'DRAFT'
            campaign.is_sent = False
            campaign.recipient_count = 0
            campaign.views_count = 0
            campaign.save()
            return Response(CampaignSerializer(campaign, context={'request': request}).data)
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def publish(self, request, pk=None):
        """Publish the campaign, making it visible to donors and notifying matching target group."""
        try:
            campaign = Campaign.objects.get(pk=pk)
            from .services import publish_campaign_helper
            publish_campaign_helper(campaign)
            return Response({'message': f'Campaign published and targeted to {campaign.recipient_count} donors.'})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)


    @action(detail=True, methods=['post'])
    def unpublish(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            campaign.status = 'DRAFT'
            campaign.save()
            return Response({'message': 'Campaign set back to Draft.'})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            campaign.status = 'ARCHIVED'
            campaign.save()
            return Response({'message': 'Campaign archived successfully.'})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def restore(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            campaign.status = 'PUBLISHED'
            campaign.save()
            return Response({'message': 'Campaign restored to Published.'})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def increment_views(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            campaign.views_count += 1
            campaign.save()
            return Response({'views_count': campaign.views_count})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['get'])
    def participants(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            regs = campaign.registrations.all()
            
            search_query = request.query_params.get('search', '')
            if search_query:
                regs = regs.filter(donor__user__full_name__icontains=search_query)
                
            blood_group = request.query_params.get('blood_group', '')
            if blood_group:
                regs = regs.filter(donor__user__blood_group__iexact=blood_group)
                
            status_filter = request.query_params.get('status', '')
            if status_filter:
                regs = regs.filter(status=status_filter)
            else:
                regs = regs.exclude(status='CANCELLED')
                
            serializer = CampaignRegistrationSerializer(regs, many=True)
            return Response(serializer.data)
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def approve_registration(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            donor_id = request.data.get('donor_id')
            reg = campaign.registrations.get(donor_id=donor_id)
            reg.status = 'APPROVED'
            reg.save()
            
            from notifications.models import Notification
            Notification.objects.create(
                recipient=reg.donor.user,
                notification_type='CAMPAIGN',
                title="RSVP Approved!",
                message=f"Your RSVP registration for '{campaign.title}' has been APPROVED by the hospital.",
                data={'campaign_id': campaign.id}
            )
            return Response({'status': reg.status})
        except (Campaign.DoesNotExist, CampaignRegistration.DoesNotExist):
            return Response({'error': 'Registration not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def reject_registration(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            donor_id = request.data.get('donor_id')
            reg = campaign.registrations.get(donor_id=donor_id)
            reg.status = 'REJECTED'
            reg.save()
            
            from notifications.models import Notification
            Notification.objects.create(
                recipient=reg.donor.user,
                notification_type='CAMPAIGN',
                title="RSVP Declined",
                message=f"Your RSVP registration for '{campaign.title}' has been declined.",
                data={'campaign_id': campaign.id}
            )
            return Response({'status': reg.status})
        except (Campaign.DoesNotExist, CampaignRegistration.DoesNotExist):
            return Response({'error': 'Registration not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['post'])
    def attendance_check(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            donor_id = request.data.get('donor_id')
            donated = request.data.get('donated', False)
            reg = campaign.registrations.get(donor_id=donor_id)
            reg.status = 'ATTENDED'
            reg.donated = donated
            reg.save()
            
            if donated:
                reg.donor.points += 50
                reg.donor.save()
                
            return Response({'status': reg.status, 'donated': reg.donated})
        except (Campaign.DoesNotExist, CampaignRegistration.DoesNotExist):
            return Response({'error': 'Registration not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['get'])
    def statistics(self, request, pk=None):
        try:
            campaign = Campaign.objects.get(pk=pk)
            regs = campaign.registrations.exclude(status='CANCELLED')
            
            total_rsvps = regs.count()
            attendance = regs.filter(status='ATTENDED').count()
            donated_count = regs.filter(donated=True).count()
            
            completion_rate = 0.0
            if total_rsvps > 0:
                completion_rate = (donated_count / total_rsvps) * 100.0
                
            return Response({
                'views': campaign.views_count,
                'registrations': total_rsvps,
                'attendance': attendance,
                'successful_donations': donated_count,
                'completion_rate': round(completion_rate, 1)
            })
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=True, methods=['get'])
    def export_participants(self, request, pk=None):
        import csv
        from django.http import HttpResponse
        try:
            campaign = Campaign.objects.get(pk=pk)
            regs = campaign.registrations.exclude(status='CANCELLED')
            
            response = HttpResponse(content_type='text/csv')
            response['Content-Disposition'] = f'attachment; filename="campaign_{campaign.id}_participants.csv"'
            
            writer = csv.writer(response)
            writer.writerow(['Donor ID', 'Name', 'Email', 'Phone', 'Blood Group', 'RSVP Status', 'Attended', 'Donated'])
            
            for reg in regs:
                writer.writerow([
                    reg.donor.donor_code,
                    reg.donor.user.full_name,
                    reg.donor.user.email,
                    reg.donor.user.phone_number,
                    reg.donor.user.blood_group,
                    reg.status,
                    'Yes' if reg.status == 'ATTENDED' else 'No',
                    'Yes' if reg.donated else 'No'
                ])
            return response
        except Campaign.DoesNotExist:
            return HttpResponse('Campaign not found', status=404)
