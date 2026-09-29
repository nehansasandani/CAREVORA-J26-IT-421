import {
  Home,
  Brain,
  Gamepad2,
  CalendarDays,
  User,
  LogOut,
  Play,
  Clock,
  Heart,
} from "lucide-react";

function ElderlyHome() {
  const user = JSON.parse(localStorage.getItem("user"));

  const handleLogout = () => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    window.location.href = "/login";
  };

  return (
    <div className="elderly-dashboard">

      {/* Sidebar */}
      <aside className="elderly-sidebar">

        <div className="elderly-logo">
          <div className="elderly-logo-icon">♥</div>

          <div>
            <h2>CAREVORA</h2>
            <span>COMPASSIONATE CARE</span>
          </div>
        </div>

        <nav className="elderly-menu">

          <div className="elderly-menu-item active">
            <Home size={19} />
            <span>Home</span>
          </div>

          <div className="elderly-menu-item">
            <Brain size={19} />
            <span>Cognitive Assessment</span>
          </div>

          <div className="elderly-menu-item">
            <Gamepad2 size={19} />
            <span>Activities & Games</span>
          </div>

          <div className="elderly-menu-item">
            <CalendarDays size={19} />
            <span>My Schedule</span>
          </div>

          <div className="elderly-menu-item">
            <User size={19} />
            <span>My Profile</span>
          </div>

        </nav>

        <button
          className="elderly-logout"
          onClick={handleLogout}
        >
          <LogOut size={18} />
          <span>Log Out</span>
        </button>

      </aside>


      {/* Main Content */}
      <main className="elderly-main">

        {/* Header */}
        <header className="elderly-header">

          <div>
            <h1>
              Good morning, {user?.name || "there"}! 👋
            </h1>

            <p>
              Welcome back to Carevora. Let's have a good day!
            </p>
          </div>

          <div className="elderly-date">
            <Clock size={18} />

            <div>
              <strong>Today</strong>
              <span>12 May 2025</span>
            </div>
          </div>

        </header>


        {/* Welcome Card */}
        <section className="elderly-welcome-card">

          <div>
            <span className="welcome-label">
              TODAY'S WELLNESS
            </span>

            <h2>
              Take some time for yourself today 🌷
            </h2>

            <p>
              Try an activity, complete your assessment,
              or simply enjoy your day.
            </p>
          </div>

          <div className="welcome-heart">
            <Heart size={55} />
          </div>

        </section>


        {/* Quick Actions */}
        <section>

          <h2 className="elderly-section-title">
            What would you like to do?
          </h2>

          <div className="elderly-action-grid">

            <div className="elderly-action-card cognitive-card">

              <div className="action-icon">
                <Brain size={28} />
              </div>

              <h3>Cognitive Assessment</h3>

              <p>
                Complete today's simple cognitive activities.
              </p>

              <button className="elderly-primary-button">
                Start Assessment
                <Play size={15} />
              </button>

            </div>


            <div className="elderly-action-card games-card">

              <div className="action-icon">
                <Gamepad2 size={28} />
              </div>

              <h3>Activities & Games</h3>

              <p>
                Enjoy some fun puzzles and activities.
              </p>

              <button className="elderly-secondary-button">
                View Activities
                <Play size={15} />
              </button>

            </div>

          </div>

        </section>


        {/* Recommended Activities */}
        <section className="recommended-section">

          <div className="section-heading-row">
            <div>
              <h2 className="elderly-section-title">
                Recommended Activities
              </h2>

              <p>
                Activities you can enjoy today
              </p>
            </div>

            <button className="view-all-button">
              View All
            </button>
          </div>


          <div className="activity-grid">

            <div className="activity-card">

              <div className="activity-image memory">
                🧩
              </div>

              <div className="activity-content">
                <span className="activity-category">
                  MEMORY
                </span>

                <h3>Memory Puzzle</h3>

                <p>
                  A simple puzzle to exercise your memory.
                </p>

                <button>
                  Start Activity →
                </button>
              </div>

            </div>


            <div className="activity-card">

              <div className="activity-image attention">
                🎯
              </div>

              <div className="activity-content">
                <span className="activity-category">
                  ATTENTION
                </span>

                <h3>Focus Game</h3>

                <p>
                  Try this simple activity at your own pace.
                </p>

                <button>
                  Start Activity →
                </button>
              </div>

            </div>


            <div className="activity-card">

              <div className="activity-image music">
                🎵
              </div>

              <div className="activity-content">
                <span className="activity-category">
                  WELLNESS
                </span>

                <h3>Music Activity</h3>

                <p>
                  Relax and enjoy a pleasant music activity.
                </p>

                <button>
                  Start Activity →
                </button>
              </div>

            </div>

          </div>

        </section>

      </main>

    </div>
  );
}

export default ElderlyHome;