"""
Mobile Money payment provider stubs.

Replace stub implementations with real API calls once MTN/Orange credentials
are configured in .env (MTN_API_KEY, MTN_API_URL, ORANGE_API_KEY, ORANGE_API_URL).
"""

from __future__ import annotations

import logging
import uuid
from abc import ABC, abstractmethod
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from decouple import config

logger = logging.getLogger(__name__)


@dataclass
class PaymentResult:
    success: bool
    transaction_id: str
    external_reference: str
    status: str
    response_data: dict[str, Any]
    message: str = ''


class BasePaymentProvider(ABC):
    """Extension point for mobile money providers."""

    @abstractmethod
    def initiate(self, amount: Decimal, phone_number: str, reference: str) -> PaymentResult:
        raise NotImplementedError

    @abstractmethod
    def verify(self, external_reference: str) -> PaymentResult:
        raise NotImplementedError


class CampayPaymentProvider(BasePaymentProvider):
    """Campay payment gateway provider for Cameroon Mobile Money."""

    def __init__(self, method: str = 'MTN_MOMO') -> None:
        from django.conf import settings
        self.username = getattr(settings, 'CAMPAY_USERNAME', '')
        self.password = getattr(settings, 'CAMPAY_PASSWORD', '')
        self.token = getattr(settings, 'CAMPAY_TOKEN', '')
        self.environment = getattr(settings, 'CAMPAY_ENVIRONMENT', 'sandbox')
        self.method = method

        if self.environment == 'sandbox':
            self.base_url = "https://demo.campay.net/api"
        else:
            self.base_url = "https://www.campay.net/api"

    def _get_auth_token(self) -> str:
        # Use permanent token directly if configured
        if self.token:
            return self.token

        import urllib.request
        import json
        url = f"{self.base_url}/token/"
        data = json.dumps({
            "username": self.username,
            "password": self.password
        }).encode('utf-8')
        req = urllib.request.Request(
            url,
            data=data,
            headers={'Content-Type': 'application/json'}
        )
        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                resp = json.loads(response.read().decode('utf-8'))
                return resp.get('token', '')
        except Exception as e:
            logger.error(f"Campay failed to retrieve dynamic token: {e}")
            return self.token or ''

    def initiate(self, amount: Decimal, phone_number: str, reference: str) -> PaymentResult:
        import urllib.request
        import json

        logger.info("[Campay] Starting payment initiation process...")

        # 11. Verify credentials load status
        if not self.username or not self.password or not self.token:
            logger.warning(f"[Campay] Missing credentials: username={bool(self.username)}, password={bool(self.password)}, token={bool(self.token)}")
        else:
            logger.info("[Campay] API Credentials are correctly loaded from environment.")

        # 4. Validate required parameters
        if amount is None or amount <= 0:
            raise ValueError("Payment amount must be greater than 0.")
        if not phone_number or not phone_number.strip():
            raise ValueError("Phone number is required.")
        if not reference or not reference.strip():
            raise ValueError("Transaction reference is required.")

        # Format phone number for Cameroon (must have 237 prefix)
        phone = phone_number.strip().replace(' ', '').replace('+', '')
        if not phone.startswith('237'):
            phone = f"237{phone}"

        # Validate phone length/prefix
        if len(phone) < 12:
            raise ValueError(f"Phone number '{phone}' is invalid. Must contain Cameroon country prefix +237.")

        # 12. Verify authentication check / token retrieval
        logger.info("[Campay] Authenticating with Campay gateway...")
        token = self._get_auth_token()
        if not token:
            logger.error("[Campay] Authentication failed. Token could not be retrieved.")
            raise ValueError("Failed to authenticate with Campay payment gateway.")
        logger.info("[Campay] Authentication successful. Token retrieved.")

        url = f"{self.base_url}/collect/"
        payload = {
            "amount": str(int(amount)),
            "currency": "XAF",
            "from": phone,
            "description": f"LifeLink Payment Ref {reference}",
            "external_reference": reference
        }

        # 7. Print the complete request sent from Django to Campay
        print("--- Outgoing Request Sent from Django to Campay ---", flush=True)
        print(f"URL: {url}", flush=True)
        print(f"Headers: Content-Type: application/json, Authorization: Token {token[:10]}...", flush=True)
        print(f"Payload: {json.dumps(payload, indent=2)}", flush=True)

        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Token {token}'
            }
        )

        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                raw_response = response.read().decode('utf-8')

                # 8. Print the complete response returned by Campay
                print("--- Complete Response Returned by Campay ---", flush=True)
                print(f"Response Body: {raw_response}", flush=True)

                resp = json.loads(raw_response)
                campay_ref = resp.get('reference', '')

                return PaymentResult(
                    success=True,
                    transaction_id=reference,
                    external_reference=campay_ref,
                    status='PENDING',
                    response_data=resp,
                    message='Campay USSD push initiated successfully.'
                )
        except Exception as e:
            logger.error(f"Campay initiation failed: {e}")
            if hasattr(e, 'read'):
                try:
                    error_body = e.read().decode('utf-8')
                    print("--- Complete Error Response Returned by Campay ---", flush=True)
                    print(f"Error Body: {error_body}", flush=True)
                    try:
                        err_json = json.loads(error_body)
                        if 'message' in err_json:
                            raise ValueError(err_json['message'])
                        elif 'detail' in err_json:
                            raise ValueError(err_json['detail'])
                    except json.JSONDecodeError:
                        pass
                except Exception:
                    pass

            if self.environment == 'sandbox':
                logger.info("Campay Sandbox fallback mode active")
                mock_ref = f"CAMPAY-MOCK-{uuid.uuid4().hex[:12].upper()}"
                return PaymentResult(
                    success=True,
                    transaction_id=reference,
                    external_reference=mock_ref,
                    status='PENDING',
                    response_data={'provider': 'Campay', 'mode': 'sandbox_mock', 'details': str(e)},
                    message='Campay sandbox mock payment initiated (stub fallback).'
                )
            raise ValueError(f"Campay payment initiation failed: {e}")

    def verify(self, external_reference: str) -> PaymentResult:
        if external_reference.startswith('CAMPAY-MOCK'):
            return PaymentResult(
                success=True,
                transaction_id=external_reference,
                external_reference=external_reference,
                status='SUCCESS',
                response_data={'provider': 'Campay', 'verified': True, 'mock': True},
                message='Campay mock payment verified successfully.'
            )

        import urllib.request
        import json
        
        logger.info(f"[Campay] Starting status verification for reference: {external_reference}")
        token = self._get_auth_token()
        url = f"{self.base_url}/transaction/{external_reference}/"

        print("--- Outgoing Request Sent from Django to Campay (Status Check) ---", flush=True)
        print(f"URL: {url}", flush=True)
        print(f"Headers: Authorization: Token {token[:10]}...", flush=True)

        req = urllib.request.Request(
            url,
            headers={
                'Authorization': f'Token {token}'
            }
        )

        try:
            with urllib.request.urlopen(req, timeout=20) as response:
                raw_response = response.read().decode('utf-8')
                
                print("--- Complete Response Returned by Campay (Status Check) ---", flush=True)
                print(f"Response Body: {raw_response}", flush=True)

                resp = json.loads(raw_response)
                status_raw = resp.get('status', '').upper()
                status = 'PENDING'
                if status_raw == 'SUCCESSFUL':
                    status = 'SUCCESS'
                elif status_raw == 'FAILED':
                    status = 'FAILED'

                return PaymentResult(
                    success=(status == 'SUCCESS'),
                    transaction_id=resp.get('external_reference', external_reference),
                    external_reference=external_reference,
                    status=status,
                    response_data=resp,
                    message=f"Campay transaction status: {status_raw}"
                )
        except Exception as e:
            logger.error(f"Campay verification failed: {e}")
            if hasattr(e, 'read'):
                try:
                    error_body = e.read().decode('utf-8')
                    print("--- Complete Error Response Returned by Campay (Status Check) ---", flush=True)
                    print(f"Error Body: {error_body}", flush=True)
                except Exception:
                    pass
            return PaymentResult(
                success=False,
                transaction_id=external_reference,
                external_reference=external_reference,
                status='PENDING',
                response_data={'error': str(e)},
                message='Failed to fetch status from Campay.'
            )


def get_payment_provider(method: str) -> BasePaymentProvider:
    providers = {
        'MTN_MOMO': lambda: CampayPaymentProvider('MTN_MOMO'),
        'ORANGE_MONEY': lambda: CampayPaymentProvider('ORANGE_MONEY'),
        'CAMPAY': lambda: CampayPaymentProvider('CAMPAY'),
        'CARD': lambda: CampayPaymentProvider('CARD'),
        'CASH': lambda: CampayPaymentProvider('CASH'),
    }
    provider_fn = providers.get(method)
    if not provider_fn:
        return CampayPaymentProvider(method)
    return provider_fn()


def generate_pdf_invoice(payment, invoice_number: str) -> str:
    """Dynamically generates a styled PDF invoice for a successful payment using ReportLab."""
    try:
        import os
        from django.conf import settings
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib import colors

        os.makedirs(os.path.join(settings.MEDIA_ROOT, 'invoices'), exist_ok=True)
        pdf_filename = f"{invoice_number}.pdf"
        pdf_path = os.path.join(settings.MEDIA_ROOT, 'invoices', pdf_filename)

        doc = SimpleDocTemplate(
            pdf_path,
            pagesize=letter,
            rightMargin=40,
            leftMargin=40,
            topMargin=40,
            bottomMargin=40
        )
        story = []
        
        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            'InvoiceTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#C62828'),
            spaceAfter=15
        )
        normal_style = styles['Normal']
        bold_style = ParagraphStyle(
            'InvoiceBold',
            parent=normal_style,
            fontName='Helvetica-Bold'
        )
        
        story.append(Paragraph("LifeLink Payment Invoice", title_style))
        story.append(Paragraph(f"Invoice Number: {invoice_number}", bold_style))
        story.append(Spacer(1, 15))
        
        payment_type_display = "Hospital Subscription" if payment.payment_type == 'HOSPITAL_SUBSCRIPTION' else "Blood Request Payment"
        
        # Detail table data
        data = [
            [Paragraph("Payment Category", bold_style), Paragraph(payment_type_display, normal_style)],
            [Paragraph("Amount Paid", bold_style), Paragraph(f"{payment.amount} FCFA", normal_style)],
            [Paragraph("Payment Method", bold_style), Paragraph(payment.payment_method, normal_style)],
            [Paragraph("Transaction ID", bold_style), Paragraph(payment.transaction_id, normal_style)],
            [Paragraph("Reference", bold_style), Paragraph(payment.transaction_reference or "N/A", normal_style)],
            [Paragraph("Status", bold_style), Paragraph("SUCCESS", normal_style)],
            [Paragraph("Paid At", bold_style), Paragraph(str(payment.paid_at)[:19] if payment.paid_at else "N/A", normal_style)]
        ]
        
        # If subscription payment, add subscription period
        if payment.payment_type == 'HOSPITAL_SUBSCRIPTION':
            try:
                sub = payment.hospital.subscription
                data.append([Paragraph("Subscription Valid Until", bold_style), Paragraph(str(sub.expiration_date)[:10], normal_style)])
            except Exception:
                pass

        table = Table(data, colWidths=[200, 300])
        table.setStyle(TableStyle([
            ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
            ('PADDING', (0,0), (-1,-1), 8),
            ('BACKGROUND', (0,0), (0,-1), colors.HexColor('#EEEEEE')),
        ]))
        
        story.append(table)
        story.append(Spacer(1, 40))
        story.append(Paragraph("Thank you for your payment and support in saving lives!", normal_style))
        story.append(Paragraph("LifeLink Network Cameroon", bold_style))
        
        doc.build(story)
        return f"invoices/{pdf_filename}"
    except Exception as e:
        logger.warning(f"[PDF Invoice] Failed to render PDF invoice for {invoice_number}: {e}")
        return f"invoices/{invoice_number}.pdf"


def process_successful_payment(
    payment_id: int,
    transaction_reference: str | None = None,
    phone_number: str | None = None,
    payment_method: str | None = None,
    amount: Decimal | None = None,
    paid_at: Any | None = None,
    response_data: dict[str, Any] | None = None
) -> Any:
    """Processes a successful payment, renewing subscriptions/confirming requests atomically."""
    from django.db import transaction
    from django.utils import timezone
    from django.contrib.auth import get_user_model
    from django.db.models import Q
    from payments.models import Payment, HospitalSubscription, Invoice, Receipt
    from requests.models import BloodRequest
    from hospitals.models import Hospital, HospitalStaff
    from notifications.models import Notification
    from audit.models import AuditLog

    User = get_user_model()
    logger.info(f"[PaymentsTrace] Atomic processing started for payment ID {payment_id}")

    with transaction.atomic():
        try:
            payment = Payment.objects.select_for_update().get(id=payment_id)
        except Payment.DoesNotExist:
            logger.error(f"[PaymentsTrace] Payment ID {payment_id} not found in database.")
            return None

        if payment.status == 'SUCCESS':
            logger.info(f"[PaymentsTrace] Payment ID {payment_id} is already marked SUCCESS. Skipping redundant processing.")
            return payment

        # 1. Update Payment record fields
        payment.status = 'SUCCESS'
        payment.payment_status = 'SUCCESS'
        payment.paid_at = paid_at or timezone.now()
        
        if transaction_reference:
            payment.transaction_reference = transaction_reference
        if phone_number:
            payment.phone_number = phone_number
        if payment_method:
            payment.payment_method = payment_method
        if amount:
            payment.amount = amount
        if response_data:
            payment.response_data = response_data
            
        payment.save()
        logger.info(f"[PaymentsTrace] Payment ID {payment_id} saved as SUCCESS. Ref: {payment.transaction_reference}, Method: {payment.payment_method}, Amount: {payment.amount}")

        # Unique identifier formatting
        invoice_number = f"INV-{(payment.payment_type or 'PAY')[:3]}-{timezone.now().strftime('%Y%m%d')}-{payment.id:05d}"
        receipt_number = f"RCPT-{(payment.payment_type or 'PAY')[:3]}-{timezone.now().strftime('%Y%m%d')}-{payment.id:05d}"

        # 2. Generate PDF & create Invoice record safely
        pdf_path = generate_pdf_invoice(payment, invoice_number)
        invoice, _ = Invoice.objects.get_or_create(
            payment=payment,
            invoice_number=invoice_number,
            defaults={
                'downloadable_format': pdf_path,
                'pdf_invoice': pdf_path
            }
        )
        logger.info(f"[PaymentsTrace] Invoice {invoice_number} generated and linked to Payment ID {payment_id}.")

        # 3. Generate & Save Receipt in Receipts section
        payer_name = payment.user.full_name if payment.user else (payment.hospital.name if payment.hospital else "Customer")
        receipt, _ = Receipt.objects.get_or_create(
            receipt_number=receipt_number,
            defaults={
                'payment': payment,
                'amount': payment.amount,
                'payer_name': payer_name,
                'payment_method': payment.payment_method,
                'transaction_reference': payment.transaction_reference or payment.transaction_id,
                'pdf_receipt': pdf_path
            }
        )
        logger.info(f"[PaymentsTrace] Receipt {receipt_number} created and saved in Receipts section.")

        # 4. Handle Hospital Subscription Payments
        if payment.payment_type == 'HOSPITAL_SUBSCRIPTION' and payment.hospital:
            hospital = payment.hospital
            months = max(1, int(payment.amount // 25)) if payment.amount else 1
            payment_date = payment.paid_at or timezone.now()
            
            # Extend hospital subscription using exact calendar months
            new_exp_date = hospital.extend_subscription(months=months, payment_date=payment_date)
            start_date = payment_date

            sub, created = HospitalSubscription.objects.get_or_create(
                hospital=hospital,
                defaults={
                    'start_date': start_date,
                    'expiration_date': new_exp_date,
                    'active_status': True
                }
            )
            if not created:
                sub.expiration_date = new_exp_date
                sub.active_status = True
                sub.save()

            # Record or update HospitalSubscriptionPayment audit record
            from payments.models import HospitalSubscriptionPayment
            sub_payment, _ = HospitalSubscriptionPayment.objects.get_or_create(
                transaction_id=payment.transaction_id,
                defaults={
                    'hospital': hospital,
                    'staff_user': payment.user,
                    'amount': payment.amount,
                    'months': months,
                    'payment_method': payment.payment_method,
                    'status': 'SUCCESS',
                    'invoice_number': invoice_number,
                    'phone_number': payment.phone_number,
                    'external_reference': payment.transaction_reference or payment.external_reference or payment.transaction_id,
                    'paid_at': payment_date,
                    'subscription_period_start': start_date,
                    'subscription_period_end': new_exp_date,
                    'response_data': payment.response_data,
                }
            )
            if sub_payment.status != 'SUCCESS':
                sub_payment.status = 'SUCCESS'
                sub_payment.paid_at = payment_date
                sub_payment.subscription_period_start = start_date
                sub_payment.subscription_period_end = new_exp_date
                sub_payment.save()

            logger.info(f"[PaymentsTrace] Hospital '{hospital.name}' subscription activated until {new_exp_date.strftime('%Y-%m-%d %H:%M:%S')}")


            # Notify paying user
            if payment.user:
                Notification.objects.create(
                    recipient=payment.user,
                    notification_type='HOSPITAL_SUBSCRIPTION',
                    title='Hospital Subscription Payment Successful',
                    message=f"Payment of {payment.amount:,.0f} FCFA for {hospital.name} was successful. Invoice #{invoice_number}. Subscription is now ACTIVE until {sub.expiration_date.strftime('%d %b %Y')}.",
                    data={'hospital_id': hospital.id, 'invoice_number': invoice_number, 'receipt_number': receipt_number}
                )

            # Notify all hospital staff members
            hospital_staff_users = User.objects.filter(hospital_staff__hospital=hospital)
            for staff in hospital_staff_users:
                if staff != payment.user:
                    Notification.objects.create(
                        recipient=staff,
                        notification_type='HOSPITAL_SUBSCRIPTION',
                        title='Hospital Subscription Activated',
                        message=f"The subscription for '{hospital.name}' is now ACTIVE until {sub.expiration_date.strftime('%d %b %Y')}.",
                        data={'hospital_id': hospital.id, 'invoice_number': invoice_number}
                    )

            # Notify system admins
            admin_users = User.objects.filter(Q(role='system_admin') | Q(is_superuser=True))
            for admin in admin_users:
                Notification.objects.create(
                    recipient=admin,
                    notification_type='HOSPITAL_SUBSCRIPTION',
                    title='Hospital Subscription Payment Received',
                    message=f"Hospital '{hospital.name}' paid {payment.amount:,.0f} FCFA for {months} month(s). Expiration: {sub.expiration_date.strftime('%Y-%m-%d')}.",
                    data={'hospital_id': hospital.id, 'invoice_number': invoice_number}
                )

            # Broadcast new hospital activation to system if needed
            try:
                from hospitals.views import notify_all_users_new_hospital
                notify_all_users_new_hospital(hospital)
            except Exception as e:
                logger.warning(f"[PaymentsTrace] Could not broadcast new hospital notification: {e}")

        # 5. Handle Blood Request Payments
        elif payment.payment_type == 'BLOOD_REQUEST_PAYMENT' and payment.blood_request:
            req = payment.blood_request
            req.payment_status = 'PAID'
            req.payment_reference = payment.transaction_id
            
            # Automatically advance blood request workflow
            if req.status == 'PENDING':
                req.status = 'CONFIRMED'
            
            # Deduct inventory if fulfillment type is INVENTORY
            if req.fulfillment_type == 'INVENTORY':
                req.status = 'CONFIRMED'
                
                from inventory.models import BloodInventory
                from django.db.models import Sum
                
                total_available = BloodInventory.objects.filter(
                    hospital=req.hospital,
                    blood_group=req.blood_group,
                    status='available'
                ).aggregate(total=Sum('quantity'))['total'] or 0
                
                if total_available >= req.quantity:
                    remaining = req.quantity
                    inventories = BloodInventory.objects.filter(
                        hospital=req.hospital,
                        blood_group=req.blood_group,
                        status='available'
                    ).order_by('expiration_date')
                    
                    for inv in inventories:
                        if remaining <= 0:
                            break
                        if inv.quantity >= remaining:
                            inv.quantity -= remaining
                            if inv.quantity == 0:
                                inv.status = 'used'
                            inv.save()
                            remaining = 0
                        else:
                            remaining -= inv.quantity
                            inv.quantity = 0
                            inv.status = 'used'
                            inv.save()
                    logger.info(f"[PaymentsTrace] Deducted {req.quantity} units of {req.blood_group} from {req.hospital.name} inventory.")
                else:
                    logger.warning(f"[PaymentsTrace] Inventory insufficient for request #{req.id}. Marked as PAID/CONFIRMED for fulfillment.")
                    
            req.save()
            logger.info(f"[PaymentsTrace] Blood Request #{req.id} marked PAID and status updated to {req.status}.")

            # Save audit trail
            AuditLog.objects.create(
                user=payment.user,
                action='APPROVE',
                model_name='BloodRequest',
                object_id=str(req.id),
                description=f"Blood request #{req.id} paid and confirmed via {payment.payment_method}. Transaction: {payment.transaction_id}",
                changes={'status': req.status, 'payment_status': 'PAID'}
            )

            # Notify hospital staff
            staff_users = User.objects.filter(hospital_staff__hospital=req.hospital, hospital_staff__is_active=True)
            for staff in staff_users:
                Notification.objects.create(
                    recipient=staff,
                    notification_type='REQUEST_UPDATE',
                    title='Blood Request Payment Confirmed',
                    message=f"Blood request #{req.id} for {req.patient.user.full_name if req.patient and req.patient.user else 'Patient'} has been paid and confirmed.",
                    data={'request_id': req.id, 'invoice_number': invoice_number}
                )

            # Notify payer (patient/family)
            if payment.user:
                Notification.objects.create(
                    recipient=payment.user,
                    notification_type='PAYMENT',
                    title='Blood Request Payment Successful',
                    message=f"Payment of {payment.amount:,.0f} FCFA for Blood Request #{req.id} was successful. Invoice #{invoice_number}.",
                    data={'request_id': req.id, 'invoice_number': invoice_number, 'receipt_number': receipt_number}
                )

            # Notify patient user profile if different from payment user
            if req.patient and req.patient.user and req.patient.user != payment.user:
                Notification.objects.create(
                    recipient=req.patient.user,
                    notification_type='REQUEST_UPDATE',
                    title='Payment Confirmed',
                    message=f"Payment for your Blood Request #{req.id} has been confirmed. Processing underway.",
                    data={'request_id': req.id}
                )

            # Notify system admins
            admin_users = User.objects.filter(Q(role='system_admin') | Q(is_superuser=True))
            for admin in admin_users:
                Notification.objects.create(
                    recipient=admin,
                    notification_type='PAYMENT',
                    title='Blood Request Payment Received',
                    message=f"Patient paid {payment.amount:,.0f} FCFA for Blood Request #{req.id}.",
                    data={'request_id': req.id, 'invoice_number': invoice_number}
                )

        logger.info(f"[PaymentsTrace] Atomic processing completed successfully for payment ID {payment_id}")
        return payment



