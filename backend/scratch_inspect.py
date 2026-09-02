import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lifelink.settings')
django.setup()

from payments.models import Payment, HospitalSubscription, HospitalSubscriptionPayment, Invoice
from hospitals.models import Hospital

print("=== PAYMENTS ===")
for p in Payment.objects.all():
    print(f"ID: {p.id}, User: {p.user}, Hospital: {p.hospital}, Type: {p.payment_type}, Amount: {p.amount}, Status: {p.status}, TxnID: {p.transaction_id}, TxnRef: {p.transaction_reference}, Phone: {p.phone_number}, PaidAt: {p.paid_at}")

print("\n=== HOSPITAL SUBSCRIPTIONS ===")
for hs in HospitalSubscription.objects.all():
    print(f"Hospital: {hs.hospital.name}, Start: {hs.start_date}, Expire: {hs.expiration_date}, Active: {hs.active_status}")

print("\n=== HOSPITALS ===")
for h in Hospital.objects.all():
    print(f"ID: {h.id}, Name: {h.name}, SubStatus: {h.subscription_status}, SubEnd: {h.subscription_end_date}, Active: {h.is_active}")
