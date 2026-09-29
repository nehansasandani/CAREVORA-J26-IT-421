const mongoose = require("mongoose");
require('dns').setServers(['8.8.8.8', '1.1.1.1']);

async function connectDB() {
    try {
        const conn = await mongoose.connect(process.env.MONGO_URI);

        console.log(`MongoDB connected: ${conn.connection.host}`);
    } catch (error) {
        console.error("MongoDB connection failed:", error.message);
        process.exit(1);
    }
}

module.exports = connectDB;