import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';

export interface StorageResult {
  url: string;
  filename: string;
}

export interface ImageStorage {
  save(buffer: Buffer, originalName: string, mimetype: string): Promise<StorageResult>;
  delete(filename: string): Promise<void>;
}

// ─── Local (Development) Storage ────────────────────────────────────────────

export class LocalImageStorage implements ImageStorage {
  private readonly uploadDir: string;
  private readonly baseUrl: string;

  constructor(uploadDir: string, baseUrl: string) {
    this.uploadDir = uploadDir;
    this.baseUrl = baseUrl;
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  async save(buffer: Buffer, originalName: string, mimetype: string): Promise<StorageResult> {
    const ext = path.extname(originalName) || this.extFromMime(mimetype);
    const filename = `${uuidv4()}${ext}`;
    const filepath = path.join(this.uploadDir, filename);
    fs.writeFileSync(filepath, buffer);
    return {
      url: `${this.baseUrl}/uploads/${filename}`,
      filename,
    };
  }

  async delete(filename: string): Promise<void> {
    const filepath = path.join(this.uploadDir, filename);
    if (fs.existsSync(filepath)) {
      fs.unlinkSync(filepath);
    }
  }

  private extFromMime(mime: string): string {
    const map: Record<string, string> = {
      'image/jpeg': '.jpg',
      'image/png': '.png',
      'image/webp': '.webp',
      'image/gif': '.gif',
    };
    return map[mime] || '.jpg';
  }
}

// ─── Future: swap to S3/Cloudinary by implementing ImageStorage interface ─────
// export class CloudinaryStorage implements ImageStorage { ... }
// export class S3Storage implements ImageStorage { ... }
