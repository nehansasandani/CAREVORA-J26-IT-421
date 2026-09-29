import {
  Brain,
  HeartPulse,
  Activity,
  Bell,
  Clock,
  AlertTriangle,
  CheckCircle,
} from "lucide-react";

import CaregiverSidebar from "./CaregiverSidebar";


function CaregiverDashboard() {
  const user = JSON.parse(localStorage.getItem("user"));
  

  return (
    <div className="caregiver-dashboard">

      {/* Sidebar */}
        <CaregiverSidebar />


      {/* Main Content */}
      <main className="caregiver-main">

        {/* Header */}
        <header className="dashboard-header">

          <div>
            <h1>
              Welcome back, {user?.name || "Caregiver"}! 👋
            </h1>

            <p>
              Here's the overall wellness overview of your residents.
            </p>
          </div>

          <div className="header-actions">

            <button className="header-icon-button">
              <Bell size={18} />
              <span>3</span>
            </button>

            <div className="date-card">
              <Clock size={17} />

              <div>
                <strong>12 May 2025</strong>
                <small>Monday, 10:30 AM</small>
              </div>
            </div>

          </div>

        </header>


        {/* Resident Card */}
        <section className="resident-card">

          <div>
            <h2>Mr. James Perera</h2>

            <div className="resident-details">
              <span>Age: 78</span>
              <span>Role: Elderly</span>
              <span>Room No: 105</span>
            </div>

            <button className="profile-link">
              View Profile →
            </button>
          </div>

          <div className="assessment-info">
            <Clock size={16} />

            <div>
              <small>Last Assessment</small>
              <strong>12 May 2025, 10:30 AM</strong>
            </div>
          </div>

          <button className="report-button">
            View Detailed Report
          </button>

        </section>


        {/* Risk Cards */}
        <section className="risk-cards">

          <div className="risk-card">
            <div className="risk-card-header">
              <span>Cognitive Health</span>
              <Brain size={18} />
            </div>

            <strong className="risk-level cognitive">
              Moderate Risk
            </strong>

            <small>Score</small>

            <div className="score">
              0.64 <span>/1.00</span>
            </div>

            <p className="positive-change">
              ↗ ↑ 0.08 <span>from last assessment</span>
            </p>
          </div>


          <div className="risk-card">
            <div className="risk-card-header">
              <span>Emotional Wellness</span>
              <HeartPulse size={18} />
            </div>

            <strong className="risk-level high">
              High Risk
            </strong>

            <small>Score</small>

            <div className="score">
              0.78 <span>/1.00</span>
            </div>

            <p className="negative-change">
              ↗ ↑ 0.12 <span>from last assessment</span>
            </p>
          </div>


          <div className="risk-card">
            <div className="risk-card-header">
              <span>Metabolic Health</span>
              <Activity size={18} />
            </div>

            <strong className="risk-level moderate">
              Moderate Risk
            </strong>

            <small>Score</small>

            <div className="score">
              0.56 <span>/1.00</span>
            </div>

            <p className="moderate-change">
              ↗ ↑ 0.04 <span>from last assessment</span>
            </p>
          </div>


          <div className="wellness-index">

            <small>Overall Wellness Index</small>

            <div className="index-circle">
              <strong>0.62</strong>
            </div>

            <span>Moderate Risk</span>

            <p>↗ ↑ 0.06 from last assessment</p>

          </div>

        </section>


        {/* Bottom Dashboard */}
        <section className="dashboard-grid">

          {/* Risk Trend */}
          <div className="dashboard-panel">

            <div className="panel-header">
              <h3>Overall Risk Trend</h3>
              <span>(All Components)</span>
            </div>

            <div className="simple-chart">

              <div className="chart-line">
                <span>0.45</span>
                <span>0.50</span>
                <span>0.47</span>
                <span>0.55</span>
                <span>0.62</span>
              </div>

              <div className="chart-dates">
                <span>10-Apr</span>
                <span>18-Apr</span>
                <span>26-Apr</span>
                <span>02-May</span>
                <span>12-May</span>
              </div>

            </div>

            <button className="trend-link">
              View Full Trend →
            </button>

          </div>


          {/* Component Contribution */}
          <div className="dashboard-panel">

            <div className="panel-header">
              <h3>Component Contribution to Overall Risk</h3>
            </div>

            <div className="contribution-content">

              <div className="donut-chart">
                <div>
                  62%
                </div>
              </div>

              <div className="legend">

                <p>
                  <span className="legend-dot cognitive-dot"></span>
                  Cognitive Health
                  <strong>35%</strong>
                </p>

                <p>
                  <span className="legend-dot emotional-dot"></span>
                  Emotional Wellness
                  <strong>40%</strong>
                </p>

                <p>
                  <span className="legend-dot metabolic-dot"></span>
                  Metabolic Health
                  <strong>25%</strong>
                </p>

              </div>

            </div>

            <small>
              Contribution values shown here are sample dashboard data.
            </small>

          </div>


          {/* Alerts */}
          <div className="dashboard-panel">

            <div className="panel-header">
              <h3>Alerts & Notifications</h3>
              <button>View All</button>
            </div>

            <div className="alert-item high-alert">
              <AlertTriangle size={18} />

              <div>
                <strong>High Risk</strong>
                <p>
                  Emotional wellness risk is high.
                  Consider closer observation.
                </p>
              </div>
            </div>

            <div className="alert-item moderate-alert">
              <AlertTriangle size={18} />

              <div>
                <strong>Moderate Risk</strong>
                <p>
                  Cognitive risk has increased
                  since last assessment.
                </p>
              </div>
            </div>

            <div className="alert-item reminder-alert">
              <CheckCircle size={18} />

              <div>
                <strong>Reminder</strong>
                <p>
                  Metabolic assessment is due in 3 days.
                </p>
              </div>
            </div>

          </div>

        </section>


        {/* Recent Assessments */}
        <section className="recent-assessments">

          <div className="panel-header">
            <h3>Recent Assessments</h3>
          </div>

          <table>

            <thead>
              <tr>
                <th>Date & Time</th>
                <th>Cognitive</th>
                <th>Emotional</th>
                <th>Metabolic</th>
                <th>Overall Risk</th>
                <th>Assessed By</th>
                <th>Action</th>
              </tr>
            </thead>

            <tbody>

              <tr>
                <td>12 May 2025, 10:30 AM</td>
                <td><span className="table-risk moderate">0.64 Moderate</span></td>
                <td><span className="table-risk high">0.78 High</span></td>
                <td><span className="table-risk moderate">0.56 Moderate</span></td>
                <td><span className="table-risk moderate">0.62 Moderate</span></td>
                <td>Seetha N.</td>
                <td><button>Details</button></td>
              </tr>

              <tr>
                <td>05 May 2025, 10:10 AM</td>
                <td><span className="table-risk moderate">0.56 Moderate</span></td>
                <td><span className="table-risk moderate">0.66 Moderate</span></td>
                <td><span className="table-risk moderate">0.52 Moderate</span></td>
                <td><span className="table-risk moderate">0.58 Moderate</span></td>
                <td>Seetha N.</td>
                <td><button>Details</button></td>
              </tr>

              <tr>
                <td>28 Apr 2025, 09:45 AM</td>
                <td><span className="table-risk moderate">0.48 Moderate</span></td>
                <td><span className="table-risk moderate">0.55 Moderate</span></td>
                <td><span className="table-risk low">0.40 Low</span></td>
                <td><span className="table-risk moderate">0.47 Moderate</span></td>
                <td>Seetha N.</td>
                <td><button>Details</button></td>
              </tr>

            </tbody>

          </table>

          <div className="view-all">
            View All Assessments →
          </div>

        </section>

      </main>

    </div>
  );
}

export default CaregiverDashboard;