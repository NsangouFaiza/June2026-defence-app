import json
import logging
import urllib.request
import urllib.error
from django.conf import settings

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are the LifeLink AI Assistant, an empathetic, highly knowledgeable, and reliable virtual assistant integrated into the LifeLink / National Referral Hospital (NRH) blood donation and distribution platform.

Your mission is to:
1. Answer questions about blood donation (eligibility criteria, intervals, preparation, benefits, compatibilities, safety).
2. Guide users step-by-step through LifeLink features and dashboards based on their role (Donor, Patient, Hospital Staff, Lab Personnel, Administrator).
3. Offer actionable advice for emergency blood requests and hospital procedures.
4. Maintain a supportive, professional, and clear tone. Always prioritize patient and donor safety. If a query requires immediate emergency medical intervention, urge the user to call emergency services or submit an Emergency Request on LifeLink immediately.

Knowledge Base:
- Platform Name: LifeLink (partnered with NRH and regional hospital network).
- Blood Groups: A+, A-, B+, B-, AB+, AB-, O+, O-.
- Universal Donor: O- (can donate red cells to all). Universal Recipient: AB+ (can receive from all).
- Donor Eligibility: Age 18-65 years, weight >= 50 kg, hemoglobin >= 12.5 g/dL (females) / 13.0 g/dL (males), normal blood pressure. Deferrals: tattoos/piercings (3-6 months), pregnancy (6 months postpartum), major surgery (6 months).
- Donation Intervals: 56 days (8 weeks) for men, 84-112 days (12-16 weeks) for women.
- Navigation for Donors:
  * Eligibility check: Use "Eligibility Check" on your dashboard.
  * Book Appointment: "Book Appointment" to select a hospital or campaign drive.
  * Donor Badge & Rewards: "Digital Donor Badge" and "Rewards" to track impact points.
- Navigation for Patients:
  * Regular/Emergency Requests: "Blood Request" or "Emergency Request" from the patient dashboard.
  * Search Packs: "Search Blood Packs" to see live hospital inventory.
  * Payments: MTN MoMo / Orange Money integration for processing fees with receipt history.
- Navigation for Hospital & Lab Staff:
  * Lab Dashboard: Validate donor attendance, serology screening (HIV, Hep B/C, Syphilis), sample analysis, unit quarantine or approval.
  * Blood Inventory: Track units, expiry dates, and reservations.
"""

ROLE_CONTEXTS = {
    'donor': "The current user is logged in as a BLOOD DONOR. Tailor your answers to donating blood, checking eligibility, finding blood drives, booking appointments, viewing their digital donor badge, and earning rewards.",
    'patient': "The current user is logged in as a PATIENT or recipient representative. Tailor your answers to requesting blood, urgent emergency blood search, tracking blood requests, finding nearby hospitals with blood banks, and managing payments.",
    'hospital_staff': "The current user is logged in as HOSPITAL / CLINICAL STAFF. Focus on managing blood inventory, verifying donor attendance, processing incoming blood requests, and emergency supply coordination.",
    'blood_bank_staff': "The current user is logged in as BLOOD BANK or LAB STAFF. Focus on laboratory testing, serology screening (HIV, Hep B, Hep C, Syphilis), approving/rejecting blood units, and inventory tracking.",
    'system_admin': "The current user is a SYSTEM ADMINISTRATOR. Focus on user administration, hospital subscription management, platform audits, and reports.",
    'general': "The user is exploring the LifeLink platform. Provide helpful, general guidance for both donors and patients."
}


class LifeLinkAiService:
    """Core AI Service handling LLM API calls and resilient domain knowledge fallback."""

    def __init__(self):
        self.gemini_api_key = getattr(settings, 'GEMINI_API_KEY', '') or ''
        self.openai_api_key = getattr(settings, 'OPENAI_API_KEY', '') or ''

    def get_response(self, user_message: str, role: str = 'donor', user_name: str = '', history: list = None) -> dict:
        """
        Process a user message and return an AI response along with role-relevant suggestions.
        """
        clean_role = (role or 'donor').lower()
        role_prompt = ROLE_CONTEXTS.get(clean_role, ROLE_CONTEXTS['general'])
        
        # 1. Attempt LLM API (Gemini or OpenAI) if configured
        if self.gemini_api_key:
            try:
                reply = self._call_gemini_api(user_message, clean_role, role_prompt, user_name, history)
                if reply:
                    return {
                        'status': 'success',
                        'reply': reply,
                        'source': 'gemini_api',
                        'role': clean_role,
                        'suggestions': self.get_suggestions_for_role(clean_role),
                    }
            except Exception as e:
                logger.warning(f"Gemini API call failed, falling back to local domain engine: {e}")

        if self.openai_api_key:
            try:
                reply = self._call_openai_api(user_message, clean_role, role_prompt, user_name, history)
                if reply:
                    return {
                        'status': 'success',
                        'reply': reply,
                        'source': 'openai_api',
                        'role': clean_role,
                        'suggestions': self.get_suggestions_for_role(clean_role),
                    }
            except Exception as e:
                logger.warning(f"OpenAI API call failed, falling back to local domain engine: {e}")

        # 2. Resilient Fallback: Built-in LifeLink Domain Intelligence Engine
        fallback_reply = self._generate_domain_response(user_message, clean_role, user_name)
        return {
            'status': 'success',
            'reply': fallback_reply,
            'source': 'domain_engine',
            'role': clean_role,
            'suggestions': self.get_suggestions_for_role(clean_role),
        }

    def _call_gemini_api(self, message: str, role: str, role_prompt: str, user_name: str, history: list) -> str:
        """Call Google Gemini 1.5/2.0 API using standard urllib."""
        # Use gemini-1.5-flash or gemini-2.0-flash
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={self.gemini_api_key}"
        
        greeting_context = f"The user's name is {user_name}." if user_name else ""
        system_instruction_text = f"{SYSTEM_PROMPT}\n\nContext for this session: {role_prompt}\n{greeting_context}"

        contents = []
        if history:
            for item in history[-6:]:  # Keep recent context
                role_val = 'user' if item.get('isUser', item.get('role') == 'user') else 'model'
                text_val = item.get('text', item.get('content', ''))
                if text_val:
                    contents.append({
                        "role": role_val,
                        "parts": [{"text": text_val}]
                    })

        contents.append({
            "role": "user",
            "parts": [{"text": message}]
        })

        payload = {
            "system_instruction": {
                "parts": [{"text": system_instruction_text}]
            },
            "contents": contents,
            "generationConfig": {
                "temperature": 0.4,
                "maxOutputTokens": 600,
            }
        }

        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url,
            data=data,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )

        with urllib.request.urlopen(req, timeout=12) as response:
            res_data = json.loads(response.read().decode('utf-8'))
            candidates = res_data.get('candidates', [])
            if candidates:
                parts = candidates[0].get('content', {}).get('parts', [])
                if parts:
                    return parts[0].get('text', '').strip()

        return ""

    def _call_openai_api(self, message: str, role: str, role_prompt: str, user_name: str, history: list) -> str:
        """Call OpenAI API using standard urllib."""
        url = "https://api.openai.com/v1/chat/completions"
        greeting_context = f"The user's name is {user_name}." if user_name else ""
        system_content = f"{SYSTEM_PROMPT}\n\nContext for this session: {role_prompt}\n{greeting_context}"

        messages = [{"role": "system", "content": system_content}]
        if history:
            for item in history[-6:]:
                r = 'user' if item.get('isUser', item.get('role') == 'user') else 'assistant'
                t = item.get('text', item.get('content', ''))
                if t:
                    messages.append({"role": r, "content": t})

        messages.append({"role": "user", "content": message})

        payload = {
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.4,
            "max_tokens": 600,
        }

        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {self.openai_api_key}'
            },
            method='POST'
        )

        with urllib.request.urlopen(req, timeout=12) as response:
            res_data = json.loads(response.read().decode('utf-8'))
            choices = res_data.get('choices', [])
            if choices:
                return choices[0].get('message', {}).get('content', '').strip()

        return ""

    def _generate_domain_response(self, text: str, role: str, user_name: str) -> str:
        """
        Specialized LifeLink and Blood Donation domain response engine.
        Delivers thorough, accurate, and role-aware answers.
        """
        lower = text.lower().strip()
        user_display = f" {user_name}" if user_name else ""

        # 1. Greetings
        if any(w in lower for w in ['hello', 'hi', 'hey', 'bonjour', 'salut', 'good morning', 'good afternoon', 'good evening']):
            if role == 'donor':
                return (
                    f"Hello{user_display}! I am your LifeLink AI Assistant.\n\n"
                    "I can help you check your blood donation eligibility, schedule your next donation, "
                    "track your digital badge and reward points, or locate nearby hospital donation drives. "
                    "How can I assist you today?"
                )
            elif role == 'patient':
                return (
                    f"Hello{user_display}! I am here to help you navigate LifeLink.\n\n"
                    "Whether you need to submit a blood request, create an urgent emergency request, "
                    "search hospital inventories, or track payment receipts via MTN/Orange Money, "
                    "I am ready to assist. What do you need help with?"
                )
            elif role in ['hospital_staff', 'blood_bank_staff']:
                return (
                    f"Hello{user_display}! Welcome to your LifeLink Hospital & Laboratory Assistant.\n\n"
                    "I can guide you through donor attendance validation, serology screening (HIV, Hep B/C, Syphilis), "
                    "blood inventory tracking, unit quarantine/approval, and appointment management. What would you like to review?"
                )
            else:
                return (
                    f"Hello{user_display}! Welcome to LifeLink.\n\n"
                    "I am your AI assistant for blood donation, emergency blood requests, and hospital logistics. "
                    "How can I help you today?"
                )

        # 2. Eligibility & Health Requirements
        if any(w in lower for w in ['eligible', 'eligibility', 'can i donate', 'qualify', 'age', 'weight', 'requirements']):
            return (
                "🩸 **Blood Donation Eligibility Criteria on LifeLink:**\n\n"
                "• **Age:** 18 to 65 years old.\n"
                "• **Weight:** At least 50 kg (110 lbs).\n"
                "• **Hemoglobin Level:** >= 12.5 g/dL for women, >= 13.0 g/dL for men.\n"
                "• **Blood Pressure:** Systolic 100-140 mmHg, Diastolic 60-90 mmHg.\n"
                "• **Donation Interval:** Men can donate every 56 days (8 weeks); women every 84–112 days (12–16 weeks).\n"
                "• **General Health:** You should feel well and rested on donation day, well-hydrated, and have eaten a healthy meal.\n\n"
                "💡 *Quick Action:* You can take the 1-minute interactive screening directly under the **Eligibility Check** section on your Donor Dashboard!"
            )

        # 3. Tattoos, Piercings, Medications, Surgery
        if any(w in lower for w in ['tattoo', 'piercing', 'surgery', 'pregnant', 'pregnancy', 'medication', 'medicine']):
            return (
                "🩺 **Medical Deferral Guidelines:**\n\n"
                "• **Tattoos & Piercings:** Requires a deferral of **3 to 6 months** after getting a tattoo or body piercing to ensure safety against bloodborne infections.\n"
                "• **Recent Surgery:** Minor surgery usually requires waiting until full healing; major surgery typically requires a **6-month deferral**.\n"
                "• **Pregnancy & Breastfeeding:** You must wait at least **6 months** after childbirth and until you have completed breastfeeding.\n"
                "• **Medications:** Antibiotics require waiting 48–72 hours after completion. Common pain relievers like paracetamol are generally acceptable, but blood thinners require consultation.\n\n"
                "If you are unsure about a specific medication, please consult the medical staff during your pre-donation checkup at the hospital."
            )

        # 4. Blood Compatibility & Types
        if any(w in lower for w in ['type', 'blood group', 'compatibility', 'universal donor', 'universal recipient', 'o-', 'ab+', 'o+']):
            return (
                "🧪 **Blood Group Compatibility Guide:**\n\n"
                "• **O-Negative (O-):** **Universal Red Cell Donor**. Can give red blood cells to any patient (A+, A-, B+, B-, AB+, AB-, O+, O-). Critically needed for trauma emergencies.\n"
                "• **AB-Positive (AB+):** **Universal Red Cell Recipient**. Can safely receive blood from any blood group.\n"
                "• **O-Positive (O+):** Most common blood type; can donate to O+, A+, B+, and AB+.\n"
                "• **A+ / A-:** Can donate to A and AB recipients.\n"
                "• **B+ / B-:** Can donate to B and AB recipients.\n\n"
                "Universal plasma donor is **AB**, which can be given to all blood groups!"
            )

        # 5. Emergency Requests / Patient Assistance
        if any(w in lower for w in ['emergency', 'urgent', 'need blood', 'request blood', 'save life', 'critical']):
            return (
                "🚨 **How to Submit an Emergency Blood Request on LifeLink:**\n\n"
                "1. Go to your **Patient Dashboard**.\n"
                "2. Tap the **Emergency Request** button (red beacon card).\n"
                "3. Select the required **Blood Group**, **Quantity (units)**, and target **Hospital / Referral Center**.\n"
                "4. Set the urgency to **CRITICAL** or **EMERGENCY** and submit.\n\n"
                "⚡ **What Happens Next:**\n"
                "The LifeLink system immediately alerts registered eligible donors within your geographic area and prioritizes hospital blood bank matching. You can also view live stock via **Search Blood Packs**."
            )

        # 6. Appointments & How to Donate
        if any(w in lower for w in ['appointment', 'book', 'schedule', 'where to donate', 'drive', 'campaign']):
            return (
                "📅 **Scheduling a Blood Donation on LifeLink:**\n\n"
                "1. From your **Donor Dashboard**, tap **Book Appointment**.\n"
                "2. Choose your preferred hospital (e.g. Central Hospital Yaoundé, General Hospital) or a community mobile drive.\n"
                "3. Select a convenient date and time slot.\n"
                "4. Confirm your appointment.\n\n"
                "You can also check the **Campaigns & Drives** tab to join community blood donation drives organized across your region!"
            )

        # 7. Rewards, Points, Badges
        if any(w in lower for w in ['reward', 'points', 'badge', 'leaderboard', 'rank']):
            return (
                "🏆 **LifeLink Rewards & Community Recognition:**\n\n"
                "• Every verified donation earns you **Donor Impact Points**.\n"
                "• Unlock **Digital Badges** (First-Time Donor, Bronze, Silver, Gold LifeSaver, Hero of LifeLink).\n"
                "• View your digital credential under **Digital Donor Badge** on your dashboard.\n"
                "• Check out the **Community Leaderboard** to see top donors in your city and inspire others to save lives!"
            )

        # 8. Laboratory & Staff Procedures
        if any(w in lower for w in ['lab', 'laboratory', 'serology', 'screening', 'quarantine', 'inventory', 'approve', 'reject', 'hiv', 'hepatitis', 'syphilis']):
            return (
                "🔬 **Laboratory Screening & Safety Protocol (NRH Standards):**\n\n"
                "• **Mandatory Serology Screening:** Every collected unit must be screened for HIV I/II, Hepatitis B (HBsAg), Hepatitis C (HCV), and Syphilis (VDRL/TPHA).\n"
                "• **Status Workflow:**\n"
                "  1. `PENDING`: Initial collection logged.\n"
                "  2. `AVAILABLE`: Verified non-reactive across all mandatory pathogens.\n"
                "  3. `QUARANTINED / REJECTED`: Immediately isolated if any pathogen is reactive or abnormal.\n"
                "• **Action in App:** Hospital staff can use the **Laboratory Control Center** on the Hospital Dashboard to update unit statuses, log attendance, and record screening certificates."
            )

        # 9. Payment & Fees
        if any(w in lower for w in ['pay', 'payment', 'fee', 'cost', 'momo', 'orange', 'mtn', 'receipt']):
            return (
                "💳 **Payments & Receipts on LifeLink:**\n\n"
                "• Blood donation is completely voluntary and free.\n"
                "• Hospital laboratory processing, screening, and cross-matching fees can be settled via **MTN Mobile Money** or **Orange Money** directly inside LifeLink.\n"
                "• After successful payment, a digital proof of payment and official receipt is generated under **Receipt History** on your dashboard for auditing and reimbursement."
            )

        # 10. General Platform Assistance
        return (
            "I'm here to assist you with all aspects of LifeLink and blood donation!\n\n"
            "Here are common things you can ask me:\n"
            "• *\"Am I eligible to donate blood today?\"*\n"
            "• *\"How do I make an emergency blood request?\"*\n"
            "• *\"Which blood group is compatible with O+ or AB-?\"*\n"
            "• *\"How do I book a donation appointment?\"*\n"
            "• *\"How does the laboratory screen blood for infections?\"*\n\n"
            "Feel free to ask your question in detail!"
        )

    def get_suggestions_for_role(self, role: str) -> list:
        """Provide context-aware quick suggestion chips for the chat UI."""
        clean_role = (role or 'donor').lower()
        if clean_role == 'donor':
            return [
                "Am I eligible to donate today?",
                "Can I donate if I have a tattoo?",
                "How do I book an appointment?",
                "Tell me about badges & rewards",
            ]
        elif clean_role == 'patient':
            return [
                "How to make an emergency blood request?",
                "How do I search for blood packs?",
                "Which blood group can donate to me?",
                "How do I pay with MTN or Orange Money?",
            ]
        elif clean_role in ['hospital_staff', 'blood_bank_staff', 'system_admin', 'blood_bank_admin']:
            return [
                "How to validate donor attendance?",
                "Mandatory serology screening rules",
                "How to update blood unit status?",
                "Inventory expiry & reservation guidelines",
            ]
        else:
            return [
                "Am I eligible to donate blood?",
                "How does blood compatibility work?",
                "How to submit an emergency request?",
                "What is the donation interval?",
            ]


# Singleton instance
ai_service = LifeLinkAiService()
