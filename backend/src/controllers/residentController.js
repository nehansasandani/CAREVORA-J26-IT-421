const User = require("../models/User");

const getResidents = async (req, res) => {
  try {
    const { elderHomeId } = req.query;

    if (!elderHomeId) {
      return res.status(400).json({
        message: "Elder home is required",
      });
    }

    const residents = await User.find({
      role: "elderly",
      elderHomeId: elderHomeId,
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
})
  .select("-password")
  .populate("elderHomeId", "name");

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