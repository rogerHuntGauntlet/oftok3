import AdmZip from 'adm-zip';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function extractFFmpeg() {
  try {
    console.log('Starting FFmpeg extraction...');
    
    // Get paths
    const rootDir = join(__dirname, '..');
    const zipPath = join(rootDir, 'tools', 'ffmpeg', 'ffmpeg.zip');
    const extractPath = join(rootDir, 'tools', 'ffmpeg');
    
    console.log('ZIP file path:', zipPath);
    console.log('Extract path:', extractPath);
    
    // Create AdmZip instance
    const zip = new AdmZip(zipPath);
    
    // Extract
    console.log('Extracting files...');
    zip.extractAllTo(extractPath, true);
    
    console.log('Extraction complete!');
    console.log('FFmpeg should now be available at:', join(extractPath, 'ffmpeg-6.1.1-essentials_build', 'bin', 'ffmpeg.exe'));
  } catch (error) {
    console.error('Error extracting FFmpeg:', error);
    process.exit(1);
  }
}

// Run if called directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  extractFFmpeg();
}

export { extractFFmpeg }; 