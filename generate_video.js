import Replicate from "replicate";
import { writeFile } from "node:fs/promises";

// Initialize Replicate with API token from environment variable
const replicate = new Replicate({
  auth: process.env.REPLICATE_API_TOKEN,
});

async function generateVideo() {
  try {
    console.log("Starting video generation...");
    
    const input = {
      prompt: "This video shows the majestic beauty of a waterfall cascading down a cliff into a serene lake. The waterfall, with its powerful flow, is the central focus of the video. The surrounding landscape is lush and green, with trees and foliage adding to the natural beauty of the scene"
    };

    console.log("Running Replicate model...");
    const output = await replicate.run("luma/ray", { input });

    console.log("Writing video to disk...");
    await writeFile("output.mp4", output);
    
    console.log("Video generated successfully! Check output.mp4");
  } catch (error) {
    console.error("Error generating video:", error);
  }
}

// Run the video generation
generateVideo(); 