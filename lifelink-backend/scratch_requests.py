import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lifelink.settings')
django.setup()

from requests.models import BloodRequest

print("=== BLOOD REQUESTS ===")
for r in BloodRequest.objects.all():
    print(f"ID: {r.id}, Patient: {r.patient.user.full_name if r.patient else 'None'}, Group: {r.blood_group}, Qty: {r.quantity}, Status: {r.status}, PayStatus: {r.payment_status}, PayRef: {r.payment_reference}")
