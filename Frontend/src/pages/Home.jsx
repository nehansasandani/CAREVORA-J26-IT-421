import { Link } from "react-router-dom";
import Navbar from "../components/common/Navbar";
import {
  MessageCircle,
  LineChart,
  ShieldCheck,
  Users,
  ArrowRight,
  Sparkles,
  HeartPulse,
  PlayCircle,
} from "lucide-react";

function Home() {
  return (
    <div className="home-page">

<Navbar />


      {/* =========================
          HERO SECTION
      ========================= */}
      <section className="hero" id="home">

        <div className="hero-content">

          <div className="hero-badge">
            <Sparkles size={14} />
            AI-Powered Wellness Monitoring
          </div>

          <h1>
            Caring Today,
            <br />
            <span>Protecting Tomorrow</span>
          </h1>

          <p>
            Carevora helps caregivers in elderly care homes
            monitor emotional wellness, cognitive wellness,
            metabolic wellness, and detect early signs of
            decline using AI-assisted assessments and
            intelligent insights.
          </p>

          <div className="hero-buttons">

            {/* New users */}
            <Link to="/register" className="primary-btn">
              <HeartPulse size={17} />
              Get Started
              <ArrowRight size={16} />
            </Link>

            {/* Learn more */}
            <Link to="/solution" className="secondary-btn">
              <PlayCircle size={17} />
              Learn More
            </Link>

          </div>

        </div>


        {/* Hero Image */}
        <div className="hero-image-wrapper">

          <div className="hero-image-ring">

            <div className="hero-image">

              <img
                src="/care1.jpg"
                alt="Caregiver supporting an elderly resident"
              />

            </div>

          </div>

        </div>

      </section>


      {/* =========================
          FEATURE CARDS
      ========================= */}
      <section className="feature-section" id="solution">

        <div className="feature-card">

          <div className="feature-icon">
            <MessageCircle size={22} />
          </div>

          <div>
            <h3>AI Assistant</h3>

            <p>
              Interactive assessments through natural
              human interaction.
            </p>
          </div>

        </div>


        <div className="feature-card">

          <div className="feature-icon">
            <LineChart size={22} />
          </div>

          <div>
            <h3>Smart Analysis</h3>

            <p>
              AI models analyze assessment responses
              and identify patterns.
            </p>
          </div>

        </div>


        <div className="feature-card">

          <div className="feature-icon">
            <ShieldCheck size={22} />
          </div>

          <div>
            <h3>Risk Insights</h3>

            <p>
              Clear risk insights with explanations
              and recommendations.
            </p>
          </div>

        </div>


        <div className="feature-card">

          <div className="feature-icon">
            <Users size={22} />
          </div>

          <div>
            <h3>Caregiver Support</h3>

            <p>
              Empowering caregivers with actionable
              insights for better decisions.
            </p>
          </div>

        </div>

      </section>


      {/* =========================
          LOGO / BRAND SECTION
      ========================= */}
      <section className="home-brand-section">

        <img
          src="/logo1.png"
          alt="Carevora logo"
        />

        <p>
          Compassionate Care, Smarter Tomorrow
        </p>

      </section>


      {/* =========================
          INFORMATION BAR
      ========================= */}
      <section className="info-bar">

        {/* Privacy */}
        <div className="info-item">

          <ShieldCheck size={22} />

          <div>
            <span>
              Privacy. Security. Compassion.
            </span>

            <small>
              Your data is protected with strong
              security standards.
            </small>
          </div>

        </div>


        <div className="info-divider"></div>


        {/* Care Homes */}
        <div className="info-item">

          <Users size={22} />

          <div>
            <span>
              Designed for
            </span>

            <strong>
              Care Homes
            </strong>

            <small>
              supporting elderly wellness
            </small>
          </div>

        </div>


        <div className="info-divider"></div>


        {/* AI Assessments */}
        <div className="info-item">

          <LineChart size={22} />

          <div>
            <span>
              AI-Powered
            </span>

            <strong>
              Assessments
            </strong>

            <small>
              for better insights
            </small>
          </div>

        </div>


        <div className="info-divider"></div>


        {/* Better Care */}
        <div className="info-item">

          <HeartPulse size={22} />

          <div>
            <span>
              Better Care
            </span>

            <strong>
              Better Lives
            </strong>

            <small>
              for our elderly
            </small>
          </div>

        </div>

      </section>

    </div>
  );
}

export default Home;