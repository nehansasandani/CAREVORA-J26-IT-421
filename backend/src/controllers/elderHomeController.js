const ElderHome = require("../models/ElderHome");

const createElderHome = async (req, res) => {
  try {
    const { name } = req.body;

    if (!name) {
      return res.status(400).json({
        message: "Elder home name is required",
      });
    }

    const existingHome = await ElderHome.findOne({ name });

    if (existingHome) {
      return res.status(400).json({
        message: "Elder home already exists",
      });
    }

    const elderHome = await ElderHome.create({
      name,
    });

    res.status(201).json(elderHome);
  } catch (error) {
    res.status(500).json({
      message: "Failed to create elder home",
      error: error.message,
    });
  }
};

const getElderHomes = async (req, res) => {
  try {
    const homes = await ElderHome.find().sort({ name: 1 });

    res.json(homes);
  } catch (error) {
    res.status(500).json({
      message: "Failed to fetch elder homes",
      error: error.message,
    });
  }
};

module.exports = {
  createElderHome,
  getElderHomes,
};