from django.db import models


class BloodBank(models.Model):
    """Blood Bank model."""

    name = models.CharField(max_length=200)
    address = models.TextField()
    city = models.CharField(max_length=100)
    region = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20)
    email = models.EmailField(blank=True, null=True)
    manager_name = models.CharField(max_length=200, blank=True, null=True)
    capacity = models.IntegerField(default=1000)
    current_stock = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name_plural = 'Blood Banks'

    def __str__(self):
        return self.name

    @property
    def available_capacity(self):
        return self.capacity - self.current_stock
