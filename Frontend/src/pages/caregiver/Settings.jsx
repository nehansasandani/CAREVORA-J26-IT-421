import {
  Settings as SettingsIcon,
  Bell,
  Lock,
  UserCog,
} from "lucide-react";

import CaregiverSidebar from "./CaregiverSidebar";


function Settings() {

  return (
    <div className="caregiver-dashboard">

      {/* Sidebar */}
      <CaregiverSidebar />

      {/* Main Content */}
      <main className="caregiver-main">

        <div className="dashboard-header">

          <div>
            <h1>Settings</h1>

            <p>
              Manage your Carevora preferences.
            </p>
          </div>

          <SettingsIcon size={28} />

        </div>


        <div className="settings-grid">

          <div className="foundation-card">

            <UserCog size={22} />

            <h3>Account Settings</h3>

            <p>
              Manage your caregiver account information.
            </p>

            <button className="foundation-button">
              Manage Account
            </button>

          </div>


          <div className="foundation-card">

            <Bell size={22} />

            <h3>Notifications</h3>

            <p>
              Manage alerts and notification preferences.
            </p>

            <button className="foundation-button">
              Notification Settings
            </button>

          </div>


          <div className="foundation-card">

            <Lock size={22} />

            <h3>Security</h3>

            <p>
              Manage your password and account security.
            </p>

            <button className="foundation-button">
              Security Settings
            </button>

          </div>

        </div>

      </main>

    </div>
  );
}

export default Settings;