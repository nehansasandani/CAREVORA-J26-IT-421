import { Link, useNavigate } from "react-router-dom";
import { User, Mail, Lock, Eye, EyeOff } from "lucide-react";
import { useState } from "react";
import { registerUser } from "../../services/authApi";

function Register() {
  const navigate = useNavigate();

  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [formData, setFormData] = useState({
    name: "",
    email: "",
    password: "",
    confirmPassword: "",
    role: "caregiver",
  });

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e) => {
  e.preventDefault();

  if (formData.password !== formData.confirmPassword) {
    alert("Passwords do not match.");
    return;
  }

  try {
    const data = await registerUser({
      name: formData.name,
      email: formData.email,
      password: formData.password,
      role: formData.role,
    });

    alert(data.message);

    navigate("/login");

  } catch (error) {
    alert(error.message);
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


      {/* Register Section */}
      <div className="login-section">

        <div className="login-card">

          <div className="login-header">
            <h2>Create Account</h2>

            <p>
              Create your account for <strong>Carevora</strong>
            </p>
          </div>

          <form onSubmit={handleSubmit}>

            {/* Name */}
            <div className="form-group">

              <label>Full Name</label>

              <div className="input-wrapper">

                <User size={16} />

                <input
                  type="text"
                  name="name"
                  placeholder="Enter your full name"
                  value={formData.name}
                  onChange={handleChange}
                  required
                />

              </div>

            </div>


            {/* Email */}
            <div className="form-group">

              <label>Email Address</label>

              <div className="input-wrapper">

                <Mail size={16} />

                <input
                  type="email"
                  name="email"
                  placeholder="Enter your email"
                  value={formData.email}
                  onChange={handleChange}
                  required
                />

              </div>

            </div>


            {/* Role */}
            <div className="form-group">

              <label>Account Type</label>

              <select
                name="role"
                value={formData.role}
                onChange={handleChange}
                className="role-select"
              >
                <option value="caregiver">Caregiver</option>
                <option value="elderly">Elderly Resident</option>
              </select>

            </div>


            {/* Password */}
            <div className="form-group">

              <label>Password</label>

              <div className="input-wrapper">

                <Lock size={16} />

                <input
                  type={showPassword ? "text" : "password"}
                  name="password"
                  placeholder="Create a password"
                  value={formData.password}
                  onChange={handleChange}
                  required
                />

                <button
                  type="button"
                  className="password-toggle"
                  onClick={() =>
                    setShowPassword(!showPassword)
                  }
                >
                  {showPassword ? (
                    <EyeOff size={16} />
                  ) : (
                    <Eye size={16} />
                  )}
                </button>

              </div>

            </div>


            {/* Confirm Password */}
            <div className="form-group">

              <label>Confirm Password</label>

              <div className="input-wrapper">

                <Lock size={16} />

                <input
                  type={
                    showConfirmPassword
                      ? "text"
                      : "password"
                  }
                  name="confirmPassword"
                  placeholder="Confirm your password"
                  value={formData.confirmPassword}
                  onChange={handleChange}
                  required
                />

                <button
                  type="button"
                  className="password-toggle"
                  onClick={() =>
                    setShowConfirmPassword(
                      !showConfirmPassword
                    )
                  }
                >
                  {showConfirmPassword ? (
                    <EyeOff size={16} />
                  ) : (
                    <Eye size={16} />
                  )}
                </button>

              </div>

            </div>


            {/* Register */}
            <button
              type="submit"
              className="login-submit"
            >
              CREATE ACCOUNT
            </button>

          </form>


          <p className="register-text">
            Already have an account?{" "}
            <Link to="/login">
              Login here
            </Link>
          </p>

        </div>

      </div>

    </div>
  );
}

export default Register;