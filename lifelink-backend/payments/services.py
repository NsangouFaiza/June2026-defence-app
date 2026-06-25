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


class MTNMobileMoneyProvider(BasePaymentProvider):
    """MTN MoMo sandbox/production stub."""

    def __init__(self) -> None:
        self.api_key = config('MTN_API_KEY', default='')
        self.api_url = config('MTN_API_URL', default='https://sandbox.momodeveloper.mtn.com')

    def initiate(self, amount: Decimal, phone_number: str, reference: str) -> PaymentResult:
        external_ref = f'MTN-{uuid.uuid4().hex[:12].upper()}'
        if not self.api_key:
            logger.info('MTN stub: no API key configured; simulating pending payment')
            return PaymentResult(
                success=True,
                transaction_id=reference,
                external_reference=external_ref,
                status='PENDING',
                response_data={
                    'provider': 'MTN_MOMO',
                    'mode': 'stub',
                    'amount': str(amount),
                    'phone_number': phone_number,
                    'api_url': self.api_url,
                },
                message='MTN payment initiated (stub). Configure MTN_API_KEY for live processing.',
            )

        # Extension point: call MTN Collections API here
        return PaymentResult(
            success=True,
            transaction_id=reference,
            external_reference=external_ref,
            status='PENDING',
            response_data={'provider': 'MTN_MOMO', 'mode': 'live_pending'},
            message='MTN payment request submitted.',
        )

    def verify(self, external_reference: str) -> PaymentResult:
        return PaymentResult(
            success=True,
            transaction_id=external_reference,
            external_reference=external_reference,
            status='SUCCESS',
            response_data={'provider': 'MTN_MOMO', 'verified': True},
            message='MTN payment verified (stub).',
        )


class OrangeMoneyProvider(BasePaymentProvider):
    """Orange Money stub."""

    def __init__(self) -> None:
        self.api_key = config('ORANGE_API_KEY', default='')
        self.api_url = config('ORANGE_API_URL', default='https://api.orange.com')

    def initiate(self, amount: Decimal, phone_number: str, reference: str) -> PaymentResult:
        external_ref = f'ORANGE-{uuid.uuid4().hex[:12].upper()}'
        if not self.api_key:
            logger.info('Orange stub: no API key configured; simulating pending payment')
            return PaymentResult(
                success=True,
                transaction_id=reference,
                external_reference=external_ref,
                status='PENDING',
                response_data={
                    'provider': 'ORANGE_MONEY',
                    'mode': 'stub',
                    'amount': str(amount),
                    'phone_number': phone_number,
                    'api_url': self.api_url,
                },
                message='Orange Money payment initiated (stub). Configure ORANGE_API_KEY for live processing.',
            )

        return PaymentResult(
            success=True,
            transaction_id=reference,
            external_reference=external_ref,
            status='PENDING',
            response_data={'provider': 'ORANGE_MONEY', 'mode': 'live_pending'},
            message='Orange Money payment request submitted.',
        )

    def verify(self, external_reference: str) -> PaymentResult:
        return PaymentResult(
            success=True,
            transaction_id=external_reference,
            external_reference=external_reference,
            status='SUCCESS',
            response_data={'provider': 'ORANGE_MONEY', 'verified': True},
            message='Orange Money payment verified (stub).',
        )


def get_payment_provider(method: str) -> BasePaymentProvider:
    providers = {
        'MTN_MOMO': MTNMobileMoneyProvider,
        'ORANGE_MONEY': OrangeMoneyProvider,
    }
    provider_cls = providers.get(method)
    if not provider_cls:
        raise ValueError(f'Unsupported payment method: {method}')
    return provider_cls()
