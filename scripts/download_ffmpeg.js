import { createWriteStream } from 'fs';
import { mkdir } from 'fs/promises';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import https from 'https';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const FFMPEG_URL = 'https://github.com/GyanD/codexffmpeg/releases/download/6.1.1/ffmpeg-6.1.1-essentials_build.zip';

function downloadWithRedirects(url, file, totalSize = 0, downloaded = 0, lastLog = 0) {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      // Handle redirects
      if (response.statusCode === 301 || response.statusCode === 302) {
        const redirectUrl = new URL(response.headers.location, url);
        console.log('Redirecting to:', redirectUrl.toString());
        downloadWithRedirects(redirectUrl, file, totalSize, downloaded, lastLog)
          .then(resolve)
          .catch(reject);
        return;
      }

      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download: ${response.statusCode}`));
        return;
      }

      // Get total size on first request
      if (totalSize === 0) {
        totalSize = parseInt(response.headers['content-length'], 10);
      }

      response.on('data', (chunk) => {
        downloaded += chunk.length;
        const percent = Math.round((downloaded * 100) / totalSize);

        // Log progress every 5%
        if (percent >= lastLog + 5) {
          console.log(`Downloaded: ${percent}%`);
          lastLog = percent;
        }
      });

      response.pipe(file);

      file.on('finish', () => {
        file.close();
        console.log('Download complete!');
        resolve();
      });

      response.on('error', reject);
    }).on('error', reject);
  });
}

async function downloadFFmpeg() {
  try {
    console.log('Starting FFmpeg download...');
    
    // Get paths
    const rootDir = join(__dirname, '..');
    const ffmpegDir = join(rootDir, 'tools', 'ffmpeg');
    const zipPath = join(ffmpegDir, 'ffmpeg.zip');
    
    // Create directory if it doesn't exist
    await mkdir(ffmpegDir, { recursive: true });
    
    console.log('Downloading from:', FFMPEG_URL);
    console.log('Saving to:', zipPath);
    
    const file = createWriteStream(zipPath);
    await downloadWithRedirects(FFMPEG_URL, file);
    
  } catch (error) {
    console.error('Error downloading FFmpeg:', error);
    process.exit(1);
  }
}

// Run if called directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  downloadFFmpeg();
}

export { downloadFFmpeg }; 