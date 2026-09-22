import { Link, useNavigate } from "react-router-dom";
import {
  Mail,
  Lock,
  Eye,
  EyeOff,
  LogIn,
} from "lucide-react";
import { useState } from "react";

import { loginUser } from "../../services/authApi";
import PopupMessage from "../../components/PopupMessage";

function Login() {
  const [showPassword, setShowPassword] = useState(false);

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);

  const navigate = useNavigate();

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

      const data = await loginUser({
        email,
        password,
      });

      console.log("LOGIN USER:", data.user);

      // Save login information
      localStorage.setItem("token", data.token);
      localStorage.setItem(
        "user",
        JSON.stringify(data.user)
      );

      // Redirect according to role
      if (data.user.role === "caregiver") {
        navigate("/caregiver");
      } else if (data.user.role === "elderly") {
        navigate("/elderly");
      }
    } catch (error) {
      setPopup({
        show: true,
        type: "error",
        title: "Login Failed",
        message:
          error.message ||
          "Unable to log in. Please check your email and password.",
        redirect: null,
      });
    } finally {
      setLoading(false);
    }
  };

  const closePopup = () => {
    setPopup({
      show: false,
      type: "success",
      title: "",
      message: "",
      redirect: null,
    });
  };

  return (
    <div className="login-page">

      {/* =========================
          LEFT BRANDING SECTION
      ========================= */}
      <div className="login-brand">

        <div className="brand-content">

          <div className="login-logo">
            <img
              src="/logo1.png"
              alt="Carevora logo"
            />
          </div>

          <p className="brand-description">
            AI-Powered Wellness Monitoring and
            Early Risk Detection System for
            Elderly Care Homes
          </p>

        </div>

        {/* Background Decorations */}
        <div className="brand-decoration decoration-one"></div>
        <div className="brand-decoration decoration-two"></div>

      </div>


      {/* =========================
          LOGIN SECTION
      ========================= */}
      <div className="login-section">

        <div className="login-card">

          <div className="login-header">

            <h2>Welcome Back!</h2>

            <p>
              Sign in to continue to{" "}
              <strong>Carevora</strong>
            </p>

          </div>


          <form onSubmit={handleSubmit}>

            {/* Email */}
            <div className="form-group">

              <label>Email Address</label>

              <div className="input-wrapper">

                <Mail size={16} />

                <input
                  type="email"
                  placeholder="Enter your email"
                  value={email}
                  onChange={(e) =>
                    setEmail(e.target.value)
                  }
                  required
                />

              </div>

            </div>


            {/* Password */}
            <div className="form-group">

              <label>Password</label>

              <div className="input-wrapper">

                <Lock size={16} />

                <input
                  type={
                    showPassword
                      ? "text"
                      : "password"
                  }
                  placeholder="Enter your password"
                  value={password}
                  onChange={(e) =>
                    setPassword(e.target.value)
                  }
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


            {/* Remember + Forgot */}
            <div className="login-options">

              <label className="remember">

                <input type="checkbox" />

                <span>
                  Remember me
                </span>

              </label>

              <a href="#forgot">
                Forgot password?
              </a>

            </div>


            {/* Login Button */}
            <button
              type="submit"
              className="login-submit"
              disabled={loading}
            >

              <LogIn size={16} />

              {loading
                ? "LOGGING IN..."
                : "LOGIN"}

            </button>

          </form>


          {/* Register */}
          <p className="register-text">

            Don't have an account?{" "}

            <Link to="/register">
              Register here
            </Link>

          </p>

        </div>

      </div>


      {/* =========================
          POPUP MESSAGE
      ========================= */}
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

export default Login;