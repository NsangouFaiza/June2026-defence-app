from rest_framework import serializers
from .models import Payment


class PaymentSerializer(serializers.ModelSerializer):
    hospital_name = serializers.CharField(source='hospital.name', read_only=True)
    months = serializers.SerializerMethodField()
    subscription_period_start = serializers.SerializerMethodField()
    subscription_period_end = serializers.SerializerMethodField()
    invoice_number = serializers.SerializerMethodField()

    class Meta:
        model = Payment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'paid_at']

    def get_months(self, obj):
        return max(1, int(obj.amount // 25))

    def get_subscription_period_start(self, obj):
        if obj.payment_type == 'HOSPITAL_SUBSCRIPTION' and obj.hospital:
            try:
                return obj.hospital.subscription.start_date.isoformat()
            except Exception:
                pass
        return None

    def get_subscription_period_end(self, obj):
        if obj.payment_type == 'HOSPITAL_SUBSCRIPTION' and obj.hospital:
            try:
                return obj.hospital.subscription.expiration_date.isoformat()
            except Exception:
                pass
        return None

    def get_invoice_number(self, obj):
        try:
            return obj.invoices.first().invoice_number
        except Exception:
            return None

