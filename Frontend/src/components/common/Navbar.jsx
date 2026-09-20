import { Link } from "react-router-dom";
import { Users, ArrowRight } from "lucide-react";

function Navbar() {
  return (
    <nav className="navbar">

      {/* Logo */}
      <div className="logo-section">
        <Link to="/" className="navbar-logo-link">
          <div className="logo">CAREVORA</div>
          <span>Compassionate Care, Smarter Tomorrow</span>
        </Link>
      </div>


      {/* Navigation */}
      <div className="nav-links">

        <Link to="/">
          Home
        </Link>

        <Link to="/about">
          About
        </Link>

        <Link to="/solution">
          Our Solution
        </Link>

        <Link to="/how-it-works">
          How It Works
        </Link>

        <Link to="/caregivers">
          For Caregivers
        </Link>

        <Link to="/elderly-residents">
  For Elderly
</Link>

        <Link to="/contact">
          Contact
        </Link>
  
      </div>
   


      {/* Buttons */}
      <div className="nav-buttons">

        <Link to="/login" className="login-btn">
          <Users size={15} />
          Log In
        </Link>

        <Link to="/register" className="get-started-btn">
          Get Started
          <ArrowRight size={15} />
        </Link>

   



      </div>

    </nav>
  );
}

export default Navbar;