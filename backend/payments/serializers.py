from rest_framework import serializers
from .models import Payment


class PaymentSerializer(serializers.ModelSerializer):
    hospital_name = serializers.CharField(source='hospital.name', read_only=True, default='N/A')
    staff_name = serializers.CharField(source='user.full_name', read_only=True, default='Staff Representative')
    months = serializers.SerializerMethodField()
    currency = serializers.SerializerMethodField()
    receipt_number = serializers.SerializerMethodField()
    subscription_period = serializers.SerializerMethodField()
    subscription_period_start = serializers.SerializerMethodField()
    subscription_period_end = serializers.SerializerMethodField()
    invoice_number = serializers.SerializerMethodField()
    pdf_url = serializers.SerializerMethodField()

    class Meta:
        model = Payment
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'paid_at']

    def get_months(self, obj):
        if obj.amount is not None and obj.amount > 0:
            return max(1, int(obj.amount // 25))
        return 1

    def get_currency(self, obj):
        return 'FCFA'

    def get_receipt_number(self, obj):
        try:
            rcpt = obj.receipts.first()
            if rcpt:
                return rcpt.receipt_number
        except Exception:
            pass
        return f"RCPT-{obj.id:04d}" if obj.id else None

    def get_subscription_period(self, obj):
        m = self.get_months(obj)
        return f"{m} Month(s)"

    def get_subscription_period_start(self, obj):
        if obj.payment_type == 'HOSPITAL_SUBSCRIPTION' and obj.hospital:
            if obj.paid_at:
                return obj.paid_at.isoformat()
            try:
                sub = getattr(obj.hospital, 'subscription', None)
                if sub and hasattr(sub, 'start_date') and sub.start_date:
                    return sub.start_date.isoformat()
            except Exception:
                pass
            return (obj.created_at or timezone.now()).isoformat()
        return None

    def get_subscription_period_end(self, obj):
        if obj.payment_type == 'HOSPITAL_SUBSCRIPTION' and obj.hospital:
            # First preference: hospital subscription_end_date if active
            if obj.hospital.subscription_end_date:
                return obj.hospital.subscription_end_date.isoformat()
            try:
                sub = getattr(obj.hospital, 'subscription', None)
                if sub and hasattr(sub, 'expiration_date') and sub.expiration_date:
                    return sub.expiration_date.isoformat()
            except Exception:
                pass
            # Fallback: calculate dynamically from payment date + months
            base_date = obj.paid_at or obj.created_at or timezone.now()
            months = self.get_months(obj)
            try:
                from dateutil.relativedelta import relativedelta
                return (base_date + relativedelta(months=months)).isoformat()
            except ImportError:
                import calendar
                m = base_date.month - 1 + months
                y = base_date.year + m // 12
                m = m % 12 + 1
                d = min(base_date.day, calendar.monthrange(y, m)[1])
                return base_date.replace(year=y, month=m, day=d).isoformat()
        return None


    def get_invoice_number(self, obj):
        try:
            inv = obj.invoices.first()
            if inv:
                return inv.invoice_number
        except Exception:
            pass
        return f"INV-{obj.id:04d}" if obj.id else None

    def get_pdf_url(self, obj):
        try:
            invoice = obj.invoices.first()
            if invoice and invoice.pdf_invoice:
                request = self.context.get('request')
                path = str(invoice.pdf_invoice)
                if not path.startswith('/media/') and not path.startswith('media/'):
                    path = f"media/{path}"
                if not path.startswith('/'):
                    path = f"/{path}"
                if request is not None:
                    return request.build_absolute_uri(path)
                return path
        except Exception:
            pass
        return None

