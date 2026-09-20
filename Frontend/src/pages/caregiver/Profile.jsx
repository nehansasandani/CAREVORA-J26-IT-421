import {
  User,
  Mail,
  ShieldCheck,
} from "lucide-react";

import CaregiverSidebar from "./CaregiverSidebar";


function Profile() {

  const user = JSON.parse(
    localStorage.getItem("user")
  );

  return (
    <div className="caregiver-dashboard">

      {/* Sidebar */}
      <CaregiverSidebar />

      {/* Main Content */}
      <main className="caregiver-main">

        <div className="dashboard-header">

          <div>
            <h1>My Profile</h1>

            <p>
              Manage your Carevora caregiver profile.
            </p>
          </div>

          <User size={28} />

        </div>


        <div className="profile-foundation-card">

          <div className="large-profile-avatar">

            {user?.name?.charAt(0) || "C"}

          </div>

          <div>

            <h2>
              {user?.name || "Caregiver"}
            </h2>

            <p>
              Caregiver
            </p>

          </div>

        </div>


        <div className="profile-details-grid">

          <div className="foundation-card">

            <User size={20} />

            <h3>Full Name</h3>

            <p>
              {user?.name || "Not available"}
            </p>

          </div>


          <div className="foundation-card">

            <Mail size={20} />

            <h3>Email</h3>

            <p>
              {user?.email || "Not available"}
            </p>

          </div>


          <div className="foundation-card">

            <ShieldCheck size={20} />

            <h3>Account Type</h3>

            <p>
              Caregiver
            </p>

          </div>

        </div>

      </main>

    </div>
  );
}

export default Profile;