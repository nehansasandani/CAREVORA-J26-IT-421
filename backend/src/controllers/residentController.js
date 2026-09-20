const User = require("../models/User");

const getResidents = async (req, res) => {
  try {
    const residents = await User.find({
      role: "elderly",
    }).select("-password");

    res.json(residents);

  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch residents",
      error: error.message,
    });
  }
};

const getResidentById = async (req, res) => {
  try {

    const resident = await User.findOne({
      _id: req.params.id,
      role: "elderly",
    }).select("-password");

    if (!resident) {
      return res.status(404).json({
        message: "Resident not found",
      });
    }

    res.json(resident);

  } catch (error) {

    res.status(500).json({
      message: "Failed to fetch resident",
      error: error.message,
    });

  }
};
module.exports = {
  getResidents,
  getResidentById,
};