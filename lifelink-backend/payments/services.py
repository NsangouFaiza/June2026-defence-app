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
    }
    provider_fn = providers.get(method)
    if not provider_fn:
        raise ValueError(f'Unsupported payment method: {method}')
    return provider_fn()

