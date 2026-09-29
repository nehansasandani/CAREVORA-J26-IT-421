import { useNavigate } from "react-router-dom";

import {
  Home,
  LayoutDashboard,
  Users,
  Brain,
  HeartPulse,
  Activity,
  Bell,
  BarChart3,
  ClipboardList,
  Settings,
  LogOut,
} from "lucide-react";


function CaregiverSidebar() {

  const navigate = useNavigate();

  const user = JSON.parse(
    localStorage.getItem("user")
  );

  const handleLogout = () => {

    localStorage.removeItem("token");
    localStorage.removeItem("user");

    navigate("/login");
  };


  return (





<aside className="caregiver-sidebar">

        <div className="carevora-logo">
          <div className="logo-icon">♥</div>
          <div>
            <h2>CAREVORA</h2>
            <span>COMPASSIONATE CARE, SMARTER TOMORROW</span>
          </div>
        </div>

        <nav className="sidebar-menu">
        <div
        className="sidebar-item"
        onClick={() => navigate("/")}
        >
        <Home size={18} />
        <span>Home</span>
        </div>

          <div className="sidebar-item active">
            <LayoutDashboard size={18} />
            <span>Overview</span>
          </div>

          <div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/residents")}
>
  <Users size={18} />
  <span>Residents</span>
</div>

       <div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/cognitive")}
>
  <Brain size={18} />
  <span>Cognitive Assessment</span>
</div>
       <div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/emotional")}
>
  <HeartPulse size={18} />
  <span>Emotional Wellness</span>
</div>
       <div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/metabolic")}
>
  <Activity size={18} />
  <span>Metabolic Health</span>
</div>
<div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/alerts")}
>
  <Bell size={18} />
  <span>Alerts</span>
  <span className="notification-count">3</span>
</div>

      <div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/reports")}
>
  <BarChart3 size={18} />
  <span>Reports & Analytics</span>
</div>
    <div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/care-plans")}
>
  <ClipboardList size={18} />
  <span>Care Plans</span>
</div>
<div
  className="sidebar-item"
  onClick={() => navigate("/caregiver/settings")}
>
  <Settings size={18} />
  <span>Settings</span>
</div>
         

        </nav>

<div className="sidebar-profile">

  <div
    className="profile-link-wrapper"
    onClick={() => navigate("/caregiver/profile")}
  >

    <div className="profile-avatar">
      {user?.name?.charAt(0) || "S"}
    </div>

    <div className="profile-info">
      <span>Caregiver</span>
      <strong>{user?.name || "Caregiver"}</strong>
    </div>

  </div>


<button
  className="logout-button"
  onClick={handleLogout}
>
  <LogOut size={16} />
</button>
</div>

      </aside>


  );
}


export default CaregiverSidebar;