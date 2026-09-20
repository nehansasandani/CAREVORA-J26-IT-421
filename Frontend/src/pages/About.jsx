import {
  HeartPulse,
  ShieldCheck,
  Users,
  Brain,
} from "lucide-react";

import Navbar from "../components/common/Navbar";

function About() {
  return (
    <div className="info-page">
  <Navbar />
      <section className="info-hero">
        <span className="page-badge">ABOUT CAREVORA</span>

        <h1>
          Caring for Better
          <span> Tomorrows</span>
        </h1>

        <p>
          Carevora is an AI-powered wellness monitoring and
          early-risk detection system designed to support
          elderly care homes and caregivers.
        </p>
      </section>

      <section className="about-content">

        <div className="about-logo-box">
          <img
            src="/carevora-logo.png"
            alt="Carevora logo"
          />
        </div>

        <div>
          <h2>Our Purpose</h2>

          <p>
            Carevora supports caregivers by providing
            meaningful wellness information from structured
            assessments and intelligent analysis.
          </p>

          <p>
            The system focuses on early identification of
            potential wellness risks so caregivers can give
            appropriate attention and support.
          </p>

          <div className="about-points">

            <div>
              <Brain size={22} />
              <span>AI-assisted assessments</span>
            </div>

            <div>
              <HeartPulse size={22} />
              <span>Wellness monitoring</span>
            </div>

            <div>
              <ShieldCheck size={22} />
              <span>Secure information</span>
            </div>

            <div>
              <Users size={22} />
              <span>Caregiver support</span>
            </div>

          </div>
        </div>

      </section>

    </div>
  );
}

export default About;