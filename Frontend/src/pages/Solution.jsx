import {
  Brain,
  HeartPulse,
  Activity,
  ShieldCheck,
  BarChart3,
} from "lucide-react";
import Navbar from "../components/common/Navbar";
function Solution() {
  return (
    <div className="info-page">
  <Navbar />
      <section className="info-hero">
        <span className="page-badge">OUR SOLUTION</span>

        <h1>
          Intelligent Wellness
          <span> Support for Care Homes</span>
        </h1>

        <p>
          Carevora provides AI-assisted wellness monitoring
          and early-risk insights to support caregivers in
          elderly care homes.
        </p>
      </section>

      <section className="solution-grid">

        <div className="solution-card">
          <Brain size={30} />
          <h3>Cognitive Wellness</h3>
          <p>
            Structured cognitive assessments help identify
            changes in cognitive performance and provide
            meaningful risk insights.
          </p>
        </div>

        <div className="solution-card">
          <HeartPulse size={30} />
          <h3>Emotional Wellness</h3>
          <p>
            Wellness indicators can help caregivers observe
            emotional and social wellness patterns.
          </p>
        </div>

        <div className="solution-card">
          <Activity size={30} />
          <h3>Metabolic Wellness</h3>
          <p>
            Assessment information supports monitoring of
            relevant metabolic health risks.
          </p>
        </div>

        <div className="solution-card">
          <BarChart3 size={30} />
          <h3>Intelligent Insights</h3>
          <p>
            AI-assisted analysis provides understandable
            information that can support caregiver actions.
          </p>
        </div>

      </section>

      <section className="solution-note">
        <ShieldCheck size={28} />

        <div>
          <h3>Designed for Support</h3>

          <p>
            Carevora is designed as a wellness monitoring and
            early-risk support system. Its results are intended
            to assist caregivers and do not replace professional
            medical assessment.
          </p>
        </div>
      </section>

    </div>
  );
}

export default Solution;