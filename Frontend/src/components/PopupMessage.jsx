import {
  CheckCircle,
  XCircle,
  AlertTriangle,
  Info,
  X,
} from "lucide-react";

import "./PopupMessage.css";

function PopupMessage({
  show,
  type = "success",
  title,
  message,
  onClose,
}) {
  if (!show) {
    return null;
  }

  const icons = {
    success: <CheckCircle size={28} />,
    error: <XCircle size={28} />,
    warning: <AlertTriangle size={28} />,
    info: <Info size={28} />,
  };

  return (
    <div className="popup-overlay">

      <div className={`popup-message popup-${type}`}>

        <button
          className="popup-close"
          onClick={onClose}
        >
          <X size={18} />
        </button>

        <div className="popup-icon">
          {icons[type]}
        </div>

        <h3>{title}</h3>

        <p>{message}</p>

        <button
          className="popup-button"
          onClick={onClose}
        >
          OK
        </button>

      </div>

    </div>
  );
}

export default PopupMessage;