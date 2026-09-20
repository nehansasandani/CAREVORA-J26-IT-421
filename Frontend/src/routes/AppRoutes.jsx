import { Routes, Route } from "react-router-dom";

import Home from "../pages/Home";
import Login from "../pages/auth/Login";
import Register from "../pages/auth/Register";

import CaregiverDashboard from "../pages/caregiver/CaregiverDashboard";
import ElderlyHome from "../pages/elderly/ElderlyHome";

import About from "../pages/About";
import Solution from "../pages/Solution";
import HowItWorks from "../pages/HowItWorks";
import ForCaregivers from "../pages/ForCaregivers";
import Contact from "../pages/Contact";

import ElderlyResidents from "../pages/ElderlyResidents";

import Residents from "../pages/caregiver/Residents";
import ResidentProfile from "../pages/caregiver/ResidentProfile";
import Profile from "../pages/caregiver/Profile";
import Settings from "../pages/caregiver/Settings";

function AppRoutes() {
  return (
    <Routes>

      <Route path="/" element={<Home />} />

      <Route
        path="/login"
        element={<Login />}
      />

      <Route
        path="/register"
        element={<Register />}
      />

        <Route
        path="/caregiver"
        element={<CaregiverDashboard />}
      />

      <Route
        path="/elderly"
        element={<ElderlyHome />}
      />

      <Route path="/about" element={<About />} />

<Route path="/solution" element={<Solution />} />

<Route
  path="/how-it-works"
  element={<HowItWorks />}
/>

<Route
  path="/caregivers"
  element={<ForCaregivers />}
/>

<Route path="/contact" element={<Contact />} />

<Route
  path="/elderly-residents"
  element={<ElderlyResidents />}
/>

<Route
  path="/caregiver/residents"
  element={<Residents />}
/>

<Route
  path="/caregiver/residents/:id"
  element={<ResidentProfile />}
/>

<Route
  path="/caregiver/profile"
  element={<Profile />}
/>

<Route
  path="/caregiver/settings"
  element={<Settings />}
/>

    </Routes>
  );
}

export default AppRoutes;