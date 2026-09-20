import {
  Mail,
  Phone,
  MapPin,
} from "lucide-react";
import Navbar from "../components/common/Navbar";
function Contact() {
  return (
    <div className="info-page">
<Navbar />
      <section className="info-hero">
        <span className="page-badge">CONTACT</span>

        <h1>
          We're Here to
          <span> Help</span>
        </h1>

        <p>
          Have a question about Carevora? Send us a message
          and our team will be happy to assist.
        </p>
      </section>

      <section className="contact-section">

        <div className="contact-information">

          <h2>Get in Touch</h2>

          <p>
            Contact us for more information about Carevora
            and its wellness monitoring features.
          </p>

          <div className="contact-item">
            <Mail size={22} />
            <div>
              <strong>Email</strong>
              <span>support@carevora.com</span>
            </div>
          </div>

          <div className="contact-item">
            <Phone size={22} />
            <div>
              <strong>Phone</strong>
              <span>+94 XX XXX XXXX</span>
            </div>
          </div>

          <div className="contact-item">
            <MapPin size={22} />
            <div>
              <strong>Location</strong>
              <span>Sri Lanka</span>
            </div>
          </div>

        </div>


        <form className="contact-form">

          <label>Name</label>
          <input
            type="text"
            placeholder="Enter your name"
          />

          <label>Email</label>
          <input
            type="email"
            placeholder="Enter your email"
          />

          <label>Message</label>
          <textarea
            rows="5"
            placeholder="Write your message..."
          ></textarea>

          <button type="submit">
            Send Message
          </button>

        </form>

      </section>

    </div>
  );
}

export default Contact;