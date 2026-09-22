const express = require("express");
const cors = require("cors");

const authRoutes = require("./routes/authRoutes");

const app = express();

const residentRoutes = require("./routes/residentRoutes");

const elderHomeRoutes = require("./routes/elderHomeRoutes");

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "Carevora backend is running",
  });
});

app.use("/api/auth", authRoutes);

app.use("/api/residents", residentRoutes);

app.use("/api/elder-homes", elderHomeRoutes);

module.exports = app;