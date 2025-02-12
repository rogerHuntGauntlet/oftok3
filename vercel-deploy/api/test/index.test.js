import { jest } from '@jest/globals';
import Replicate from 'replicate';
import { Storage } from '@google-cloud/storage';
import handler from '../index.js';
import fetch from 'node-fetch';

// Mock node-fetch
jest.mock('node-fetch', () => 
  jest.fn().mockImplementation((url) => {
    if (url.includes('/predictions')) {
      return Promise.resolve({
        ok: true,
        status: 200,
        json: () => Promise.resolve({
          id: 'test_prediction_id',
          status: 'starting'
        })
      });
    }
    // For video download
    return Promise.resolve({
      buffer: () => Promise.resolve(Buffer.from('test')),
    });
  })
);

// Mock external dependencies
const mockCreate = jest.fn();
const mockGet = jest.fn();

// Create a mock Replicate instance that will be used by the handler
const mockReplicateInstance = {
  predictions: {
    create: mockCreate,
    get: mockGet
  }
};

// Mock the Replicate constructor to return our mock instance
jest.mock('replicate', () => {
  return function() {
    return mockReplicateInstance;
  };
});

// Mock ffmpeg
jest.mock('fluent-ffmpeg', () => {
  return function() {
    return {
      screenshots: () => ({
        on: (event, callback) => {
          if (event === 'end') callback();
          return this;
        }
      }),
      output: () => ({
        outputOptions: () => ({
          on: (event, callback) => {
            if (event === 'end') callback();
            return this;
          }
        })
      })
    };
  };
});

// Mock fs promises
jest.mock('fs/promises', () => ({
  writeFile: jest.fn().mockResolvedValue(undefined),
  unlink: jest.fn().mockResolvedValue(undefined),
  mkdir: jest.fn().mockResolvedValue(undefined),
  readdir: jest.fn().mockResolvedValue(['playlist.m3u8']),
  rm: jest.fn().mockResolvedValue(undefined)
}));

// Mock other dependencies
jest.mock('@google-cloud/storage', () => ({
  Storage: jest.fn().mockImplementation(() => ({
    bucket: jest.fn().mockReturnValue({
      upload: jest.fn().mockResolvedValue([]),
      file: jest.fn().mockReturnValue({
        getSignedUrl: jest.fn().mockResolvedValue(['https://example.com/test.mp4'])
      })
    })
  }))
}));

// Set up environment variables before any tests run
process.env.API_SECRET_KEY = 'test_key';
process.env.REPLICATE_API_TOKEN = 'test_replicate_token';
process.env.FIREBASE_PROJECT_ID = 'test-project';
process.env.FIREBASE_STORAGE_BUCKET = 'test-bucket';
process.env.FIREBASE_SERVICE_ACCOUNT = JSON.stringify({
  type: 'service_account',
  project_id: 'test-project'
});

describe('Video Generation API', () => {
  let req;
  let res;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    mockCreate.mockReset();
    mockGet.mockReset();
    fetch.mockClear();

    // Mock response object
    res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      setHeader: jest.fn(),
      end: jest.fn()
    };
  });

  describe('POST /api/generate', () => {
    beforeEach(() => {
      req = {
        method: 'POST',
        url: '/api/generate',
        headers: {
          'authorization': 'Bearer test_key'
        },
        body: {
          prompt: 'test video'
        }
      };
    });

    test('starts video generation successfully', async () => {
      // Mock successful prediction creation
      mockCreate.mockResolvedValueOnce({
        id: 'test_prediction_id',
        status: 'starting'
      });

      await handler(req, res);

      expect(mockCreate).toHaveBeenCalledWith({
        version: "luma/ray",
        input: {
          prompt: 'test video',
          width: 1080,
          height: 1920,
          num_frames: 150,
          fps: 30
        }
      });

      expect(res.json).toHaveBeenCalledWith({
        success: true,
        id: 'test_prediction_id',
        status: 'starting'
      });
    });

    test('handles missing authorization', async () => {
      req.headers.authorization = undefined;

      await handler(req, res);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: 'Authentication required'
      });
    });

    test('handles invalid authorization', async () => {
      req.headers.authorization = 'Bearer wrong_key';

      await handler(req, res);

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({
        success: false,
        error: 'Authentication required'
      });
    });

    test('handles missing prompt', async () => {
      req.body = {};

      await handler(req, res);

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({
        error: 'Prompt is required'
      });
    });

    test('handles moderated content', async () => {
      req.body.prompt = 'nsfw content test';

      await handler(req, res);

      expect(res.json).toHaveBeenCalledWith({
        success: true,
        isModeratedContent: true
      });
    });
  });

  describe('GET /api/status/:id', () => {
    beforeEach(() => {
      req = {
        method: 'GET',
        url: '/api/status/test_prediction_id',
        headers: {
          'authorization': 'Bearer test_key'
        }
      };
    });

    test('returns prediction status', async () => {
      // Mock the Replicate API response
      mockGet.mockResolvedValueOnce({
        status: 'processing',
        output: null,
        error: null
      });

      await handler(req, res);

      expect(mockGet).toHaveBeenCalledWith('test_prediction_id');
      expect(res.json).toHaveBeenCalledWith({
        success: true,
        status: 'processing',
        progress: 0.5,
        error: null
      });
    });

    test('handles completed prediction with video processing', async () => {
      // Mock the Replicate API response
      mockGet.mockResolvedValueOnce({
        status: 'succeeded',
        output: 'https://example.com/video.mp4',
        error: null
      });

      // Mock the video processing functions
      const mockVideoPath = '/tmp/test.mp4';
      fetch.mockImplementationOnce(() => Promise.resolve({
        buffer: () => Promise.resolve(Buffer.from('test video data'))
      }));

      await handler(req, res);

      expect(mockGet).toHaveBeenCalledWith('test_prediction_id');
      expect(res.json).toHaveBeenCalledWith({
        success: true,
        status: 'succeeded',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/test.mp4',
        previewUrl: 'https://example.com/test.mp4',
        hlsUrl: 'https://example.com/test.mp4',
        progress: 1.0
      });
    });

    test('handles failed prediction', async () => {
      // Mock the Replicate API response
      mockGet.mockResolvedValueOnce({
        status: 'failed',
        error: 'Generation failed',
        output: null
      });

      await handler(req, res);

      expect(mockGet).toHaveBeenCalledWith('test_prediction_id');
      expect(res.json).toHaveBeenCalledWith({
        success: true,
        status: 'failed',
        progress: 0,
        error: 'Generation failed'
      });
    });
  });

  describe('OPTIONS request', () => {
    test('handles CORS preflight', async () => {
      req = {
        method: 'OPTIONS'
      };

      await handler(req, res);

      expect(res.setHeader).toHaveBeenCalledWith('Access-Control-Allow-Origin', '*');
      expect(res.setHeader).toHaveBeenCalledWith('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.end).toHaveBeenCalled();
    });
  });
}); 