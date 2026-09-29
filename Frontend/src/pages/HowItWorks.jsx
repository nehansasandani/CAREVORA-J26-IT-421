import {
  UserRound,
  ClipboardList,
  Brain,
  BarChart3,
  Bell,
} from "lucide-react";
import Navbar from "../components/common/Navbar";
function HowItWorks() {
  return (
    <div className="info-page">
 <Navbar />
      <section className="info-hero">
        <span className="page-badge">HOW IT WORKS</span>

        <h1>
          From Assessment to
          <span> Caregiver Insight</span>
        </h1>

        <p>
          Carevora follows a simple process to collect
          wellness information, analyze it, and provide
          useful insights for caregivers.
        </p>
      </section>

      <section className="steps-section">

        <div className="step-card">
          <div className="step-number">01</div>
          <UserRound size={28} />
          <h3>Resident Assessment</h3>
          <p>
            The elderly resident participates in structured
            wellness assessments and activities.
          </p>
        </div>

        <div className="step-card">
          <div className="step-number">02</div>
          <ClipboardList size={28} />
          <h3>Assessment Data</h3>
          <p>
            Assessment responses and relevant indicators are
            recorded by the system.
          </p>
        </div>

        <div className="step-card">
          <div className="step-number">03</div>
          <Brain size={28} />
          <h3>AI Analysis</h3>
          <p>
            AI models analyze the available assessment
            information.
          </p>
        </div>

        <div className="step-card">
          <div className="step-number">04</div>
          <BarChart3 size={28} />
          <h3>Risk Insights</h3>
          <p>
            The system generates understandable wellness
            and risk information.
          </p>
        </div>

        <div className="step-card">
          <div className="step-number">05</div>
          <Bell size={28} />
          <h3>Caregiver Support</h3>
          <p>
            Caregivers can review results, alerts and
            recommendations for appropriate follow-up.
          </p>
        </div>

      </section>

    </div>
  );
}

export default HowItWorks;