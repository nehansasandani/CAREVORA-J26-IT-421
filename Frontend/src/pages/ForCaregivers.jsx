import {
  Users,
  LayoutDashboard,
  Bell,
  FileText,
  ArrowRight,
} from "lucide-react";
import { Link } from "react-router-dom";
import Navbar from "../components/common/Navbar";
function ForCaregivers() {
  return (
    <div className="info-page">
 <Navbar />
      <section className="info-hero">
        <span className="page-badge">FOR CAREGIVERS</span>

        <h1>
          Supporting Caregivers
          <span> Every Day</span>
        </h1>

        <p>
          Carevora gives caregivers a clear view of resident
          wellness information and helps them identify cases
          that may need closer attention.
        </p>
      </section>

      <section className="caregiver-features">

        <div className="caregiver-feature">
          <LayoutDashboard size={30} />
          <h3>Wellness Dashboard</h3>
          <p>
            View an overall wellness overview of residents
            from one dashboard.
          </p>
        </div>

        <div className="caregiver-feature">
          <Users size={30} />
          <h3>Resident Management</h3>
          <p>
            Access resident information and assessment
            history.
          </p>
        </div>

        <div className="caregiver-feature">
          <Bell size={30} />
          <h3>Alerts & Notifications</h3>
          <p>
            Receive important risk information that may
            require closer observation.
          </p>
        </div>

        <div className="caregiver-feature">
          <FileText size={30} />
          <h3>Reports</h3>
          <p>
            Review detailed assessment results and wellness
            information.
          </p>
        </div>

      </section>

      <div className="caregiver-cta">
        <h2>Ready to access Carevora?</h2>

        <p>
          Log in to access the caregiver dashboard.
        </p>

        <Link to="/login" className="primary-btn">
          Log In
          <ArrowRight size={16} />
        </Link>
      </div>

    </div>
  );
}

export default ForCaregivers;