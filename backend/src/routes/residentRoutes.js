const express = require("express");

const {
  getResidents,
  getResidentById,
} = require("../controllers/residentController");

const router = express.Router();

router.get("/", getResidents);
router.get("/:id", getResidentById);

module.exports = router;