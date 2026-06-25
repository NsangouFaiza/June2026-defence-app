from django.db import models


class Report(models.Model):
    REPORT_TYPES = (
        ('MONTHLY_DONATIONS', 'Monthly Donations'),
        ('BLOOD_STOCK', 'Blood Stock'),
        ('STATISTICS', 'Statistics'),
    )

    report_type = models.CharField(max_length=30, choices=REPORT_TYPES)
    generated_by = models.ForeignKey('users.User', on_delete=models.CASCADE, related_name='reports')
    parameters = models.JSONField(default=dict, blank=True)
    file_path = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.get_report_type_display()} - {self.created_at.date()}"
