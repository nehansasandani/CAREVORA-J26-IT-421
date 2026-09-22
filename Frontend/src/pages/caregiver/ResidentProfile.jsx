import { Link, useParams } from "react-router-dom";

import {
  ArrowLeft,
  User,
  Mail,
  ShieldCheck,
  Home,
} from "lucide-react";

import { useEffect, useState } from "react";

import CaregiverSidebar from "./CaregiverSidebar";


function ResidentProfile() {

  const { id } = useParams();
  console.log("Resident ID from URL:", id);

  const [resident, setResident] = useState(null);
  const [loading, setLoading] = useState(true);

useEffect(() => {

  const fetchResident = async () => {

    try {

      console.log("Fetching resident:", id);

      const response = await fetch(
        `http://localhost:5000/api/residents/${id}`
      );

      const data = await response.json();

      console.log("Backend response:", data);

      if (!response.ok) {
        throw new Error(
          data.message || "Failed to fetch resident"
        );
      }

      setResident(data);

    } catch (error) {

      console.error(
        "Error fetching resident:",
        error
      );

      setResident(null);

    } finally {

      setLoading(false);

    }

  };

  fetchResident();

}, [id]);


  if (loading) {
    return (
      <div className="caregiver-dashboard">

        <CaregiverSidebar />

        <main className="caregiver-main">

          <p>Loading resident profile...</p>

        </main>

      </div>
    );
  }


  if (!resident) {
    return (
      <div className="caregiver-dashboard">

        <CaregiverSidebar />

        <main className="caregiver-main">

          <p>Resident not found.</p>

          <Link
            to="/caregiver/residents"
            className="back-link"
          >
            <ArrowLeft size={16} />
            Back to Residents
          </Link>

        </main>

      </div>
    );
  }


  return (

    <div className="caregiver-dashboard">

      {/* Sidebar */}
      <CaregiverSidebar />


      {/* Main Content */}
      <main className="caregiver-main">

        {/* Back */}
        <Link
          to="/caregiver/residents"
          className="back-link"
        >
          <ArrowLeft size={16} />
          Back to Residents
        </Link>


        {/* Header */}
        <div className="dashboard-header">

          <div>

            <h1>
              Resident Profile
            </h1>

            <p>
              Resident ID: {resident._id}
            </p>

          </div>

          <User size={28} />

        </div>


        {/* Profile */}
        <div className="profile-foundation-card">

          <div className="large-profile-avatar">

            {resident.name?.charAt(0) || "R"}

          </div>

          <div>

            <h2>
              {resident.name}
            </h2>

            <p>
              Elderly Resident
            </p>

          </div>

        </div>


        {/* Details */}
        <div className="profile-details-grid">

          <div className="foundation-card">

            <User size={20} />

            <h3>
              Full Name
            </h3>

            <p>
              {resident.name}
            </p>

          </div>


          <div className="foundation-card">

            <Mail size={20} />

            <h3>
              Email
            </h3>

            <p>
              {resident.email}
            </p>

          </div>


          <div className="foundation-card">

            <ShieldCheck size={20} />

            <h3>
              Account Type
            </h3>

            <p>
              {resident.role}
            </p>

          </div>

          <div className="foundation-card">

  <Home size={20} />

  <h3>
    Elder Home
  </h3>

  <p>
    {resident.elderHomeId?.name || "Not assigned"}
  </p>

</div>

        </div>

      </main>

    </div>

  );
}


export default ResidentProfile;