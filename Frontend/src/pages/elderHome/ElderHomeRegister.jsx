import { Link, useNavigate } from "react-router-dom";
import { Home } from "lucide-react";
import { useState } from "react";

import PopupMessage from "../../components/PopupMessage";

function ElderHomeRegister() {
  const navigate = useNavigate();

  const [name, setName] = useState("");
  const [loading, setLoading] = useState(false);

  const [popup, setPopup] = useState({
    show: false,
    type: "success",
    title: "",
    message: "",
    redirect: null,
  });

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      setLoading(true);

      const response = await fetch(
        "http://localhost:5000/api/elder-homes",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            name: name.trim(),
          }),
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(
          data.message || "Failed to register elder home"
        );
      }

      setName("");

      setPopup({
        show: true,
        type: "success",
        title: "Elder Home Registered",
        message:
          "The elder home has been registered successfully. You can now create a caregiver or elderly resident account.",
        redirect: "/register",
      });
    } catch (error) {
      setPopup({
        show: true,
        type: "error",
        title: "Registration Failed",
        message:
          error.message || "Something went wrong. Please try again.",
        redirect: null,
      });
    } finally {
      setLoading(false);
    }
  };

  const closePopup = () => {
    const redirect = popup.redirect;

    setPopup({
      show: false,
      type: "success",
      title: "",
      message: "",
      redirect: null,
    });

    if (redirect) {
      navigate(redirect);
    }
  };

  return (
    <div className="login-page">

      {/* Left Branding */}
      <div className="login-brand">

        <div className="brand-content">

          <div className="brand-logo">
            <img
              src="/logo1.png"
              alt="Carevora logo"
              className="register-brand-logo"
            />
          </div>

          <div className="brand-line">
            <span></span>
            <span>♥</span>
            <span></span>
          </div>

          <p className="brand-tagline">
            Compassionate Care, Smarter Tomorrow
          </p>

          <p className="brand-description">
            AI-Powered Wellness Monitoring and
            Early Risk Detection System for
            Elderly Care Homes
          </p>

        </div>

        <div className="brand-decoration decoration-one"></div>
        <div className="brand-decoration decoration-two"></div>

      </div>


      {/* Registration Section */}
      <div className="login-section">

        <div className="login-card">

          <div className="login-header">

            <h2>Register Elder Home</h2>

            <p>
              Register your elder home with{" "}
              <strong>Carevora</strong>
            </p>

          </div>


          <form onSubmit={handleSubmit}>

            <div className="form-group">

              <label>Elder Home Name</label>

              <div className="input-wrapper">

                <Home size={16} />

                <input
                  type="text"
                  placeholder="Enter elder home name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />

              </div>

            </div>


            <button
              type="submit"
              className="login-submit"
              disabled={loading}
            >
              {loading
                ? "REGISTERING..."
                : "REGISTER ELDER HOME"}
            </button>

          </form>


          <p className="register-text">

            Already have an account?{" "}

            <Link to="/login">
              Login here
            </Link>

          </p>


          <p className="register-text">

            Are you a caregiver or elderly resident?{" "}

            <Link to="/register">
              Create an account
            </Link>

          </p>

        </div>

      </div>


      {/* Popup Message */}
      <PopupMessage
        show={popup.show}
        type={popup.type}
        title={popup.title}
        message={popup.message}
        onClose={closePopup}
      />

    </div>
  );
}

export default ElderHomeRegister;