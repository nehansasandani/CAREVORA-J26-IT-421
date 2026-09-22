import { Link } from "react-router-dom";
import { Users, User, ArrowRight } from "lucide-react";
import CaregiverSidebar from "./CaregiverSidebar";
import { useEffect, useState } from "react";

function Residents() {

  const [residents, setResidents] = useState([]);
  const [loading, setLoading] = useState(true);

  const user = JSON.parse(
    localStorage.getItem("user")
  );

useEffect(() => {

  const fetchResidents = async () => {

    try {

      const response = await fetch(
  `http://localhost:5000/api/residents?elderHomeId=${user?.elderHomeId?._id || user?.elderHomeId}`
);

      const data = await response.json();

      setResidents(data);

    } catch (error) {

      console.error(
        "Error fetching residents:",
        error
      );

    } finally {

      setLoading(false);

    }
  };

  fetchResidents();

}, []);

  return (
    <div className="caregiver-dashboard">

      {/* Sidebar */}
      <CaregiverSidebar />

      {/* Main Content */}
      <main className="caregiver-main">

        {/* Header */}
        <div className="dashboard-header">

          <div>
            <h1>Residents</h1>

            <p>
              View and manage elderly residents.
            </p>
          </div>

          <Users size={28} />

        </div>


        {/* Residents */}
        <div className="resident-list">
  {loading && (
    <p>Loading residents...</p>
  )}

  {!loading && residents.length === 0 && (
    <p>No elderly residents have registered yet.</p>
  )}

  {!loading && residents.map((resident) => (

            <div
              className="foundation-card"
              key={resident._id}
            >

              <div className="resident-avatar">
                <User size={22} />
              </div>


              <div className="resident-info">

                <h3>
                  {resident.name}
                </h3>

                <p>
                Email: {resident.email}
                </p>

              </div>


              <Link
                to={`/caregiver/residents/${resident._id}`}
                className="foundation-button"
              >
                View Profile
                <ArrowRight size={15} />
              </Link>

            </div>

          ))}

        </div>

      </main>

    </div>
  );
}

export default Residents;