import { Link } from "react-router-dom";
import {
  Brain,
  HeartPulse,
  Activity,
  Gamepad2,
  Users,
  ShieldCheck,
  ArrowRight,
} from "lucide-react";

import Navbar from "../components/common/Navbar";


function ElderlyResidents() {
  return (
    <div className="info-page">
<Navbar />
      {/* Hero */}
      <section className="info-hero">
        <div className="page-badge">
          FOR ELDERLY RESIDENTS
        </div>

        <h1>
          Supporting Your
          <br />
          <span>Wellness Every Day</span>
        </h1>

        <p>
          Carevora provides simple and supportive wellness activities
          designed to help elderly residents stay engaged, active,
          and connected while supporting caregivers with useful insights.
        </p>
      </section>


      {/* Wellness Areas */}
      <section className="solution-grid">

        <div className="solution-card">
          <Brain size={48} />

          <h3>Cognitive Wellness</h3>

          <p>
            Take part in simple memory and thinking activities
            designed to encourage mental engagement in a comfortable
            and supportive way.
          </p>
        </div>


        <div className="solution-card">
          <HeartPulse size={48} />

          <h3>Emotional Wellness</h3>

          <p>
            Carevora supports activities that encourage emotional
            expression, positive interaction, and social engagement.
          </p>
        </div>


        <div className="solution-card">
          <Activity size={48} />

          <h3>Metabolic Wellness</h3>

          <p>
            Wellness information can help caregivers understand
            changes and provide appropriate support for everyday care.
          </p>
        </div>


        <div className="solution-card">
          <Gamepad2 size={48} />

          <h3>Games & Activities</h3>

          <p>
            Enjoy simple games, puzzles, and activities selected to
            encourage participation and mental engagement.
          </p>
        </div>

      </section>


      {/* How it helps */}
      <section className="solution-note">

        <Users size={28} />

        <div>
          <h3>Caregiver Support</h3>

          <p>
            Your activities and assessments can help caregivers
            understand your wellness needs and provide more
            personalized support.
          </p>
        </div>

      </section>


      {/* CTA */}
      <section className="caregiver-cta">

        <ShieldCheck size={32} />

        <h2>Wellness Support Made Simple</h2>

        <p>
          Participate at your own pace. If you need help with an
          activity, you can always ask a caregiver for assistance.
        </p>

        <Link to="/login" className="primary-btn">
          Go to Login
          <ArrowRight size={16} />
        </Link>

      </section>

    </div>
  );
}

export default ElderlyResidents;