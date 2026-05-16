export const DDPPlayer = {
  mounted() {
    this.canvas = this.el;
    this.ctx = this.canvas.getContext('2d');

    this.updateDimensions();
    
    this.timer = null;

    this.handleEvent(`ddp-frame-${this.canvas.id}`, ({ frames }) => {
      if (this.timer) {
        clearInterval(this.timer);
        this.timer = null;
      }

      if (!frames || frames.length === 0) return;
      const renderFrame = (frameData) => {
        if (Array.isArray(frameData)) {
          for (const chunk of frameData) {
            this.renderDDP(chunk);
          }
        } else {
          this.renderDDP(frameData);
        }
      };

      renderFrame(frames[0]);
      
      if (frames.length > 1) {
        let currentFrame = 1;
        this.timer = setInterval(() => {
          renderFrame(frames[currentFrame]);
          currentFrame = (currentFrame + 1) % frames.length;
        }, 100);
      }
    });
  },

  updated() {
    this.updateDimensions();
  },

  destroyed() {
    if (this.timer) clearInterval(this.timer);
  },

  updateDimensions() {
    this.width = parseInt(this.canvas.dataset.width, 10) || 0;
    this.height = parseInt(this.canvas.dataset.height, 10) || 0;

    if (this.width > 0 && this.height > 0) {
      this.canvas.width = this.width;
      this.canvas.height = this.height;
      this.imageData = this.ctx.createImageData(this.width, this.height);
    } else {
      this.imageData = null;
    }
  },

  renderDDP(base64Str) {
    if (this.width === 0 || this.height === 0 || !this.imageData) return;
    
    const binaryStr = atob(base64Str);
    const bytes = new Uint8Array(binaryStr.length);
    for (let i = 0; i < binaryStr.length; i++) {
      bytes[i] = binaryStr.charCodeAt(i);
    }

    if (bytes.length < 10) return;

    const flags = bytes[0];
    const push = (flags & 0x01) !== 0;
    const offset = ((bytes[4] << 24) | (bytes[5] << 16) | (bytes[6] << 8) | bytes[7]) >>> 0;
    
    const declaredLength = (bytes[8] << 8) | bytes[9];
    if (bytes.length - 10 < declaredLength) {
      console.error("DDP Error: Payload length shorter than declared length.");
      return;
    }

    const typeByte = bytes[2];
    const ttt = (typeByte >>> 3) & 0x07;
    const payload = bytes.slice(10, 10 + declaredLength);

    const bitsPerChannel = parseInt(this.canvas.dataset.bits || "8", 10);
    let bytesPerChannel = 1;
    if (bitsPerChannel > 8 && bitsPerChannel <= 16) bytesPerChannel = 2;
    if (bitsPerChannel > 16 && bitsPerChannel <= 24) bytesPerChannel = 3;
    if (bitsPerChannel > 24) bytesPerChannel = 4;

    const maxVal = Math.pow(2, bitsPerChannel) - 1;

    let channels = 3;
    if (ttt === 4) channels = 1; // grayscale
    if (ttt === 3) channels = 4; // RGBW
    const bytesPerPixel = channels * bytesPerChannel;

    const readChannel = (idx) => {
      if (idx + bytesPerChannel > payload.length) return 0;
      let val = 0;
      if (bytesPerChannel === 1) val = payload[idx];
      else if (bytesPerChannel === 2) val = payload[idx] | (payload[idx + 1] << 8);
      else if (bytesPerChannel === 3) val = payload[idx] | (payload[idx + 1] << 8) | (payload[idx + 2] << 16);
      else if (bytesPerChannel === 4) val = (payload[idx] | (payload[idx + 1] << 8) | (payload[idx + 2] << 16) | (payload[idx + 3] << 24)) >>> 0;
      return (val / maxVal) * 255;
    };

    const hslToRgb = (h, s, l) => {
      if (s === 0) return [l * 255, l * 255, l * 255];
      const hue2rgb = (p, q, t) => {
        if (t < 0) t += 1;
        if (t > 1) t -= 1;
        if (t < 1/6) return p + (q - p) * 6 * t;
        if (t < 1/2) return q;
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
        return p;
      };
      const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      const p = 2 * l - 1;
      return [
        hue2rgb(p, q, h + 1/3) * 255,
        hue2rgb(p, q, h) * 255,
        hue2rgb(p, q, h - 1/3) * 255
      ];
    };

    let c = 0;

    while (c < payload.length) {
      const pixelIndex = Math.floor((offset + c) / bytesPerPixel);
      const i = pixelIndex * 4;
      if (i >= this.imageData.data.length) break;
      
      if (ttt === 4) { // grayscale
        const gray = readChannel(c);
        c += bytesPerChannel;
        this.imageData.data[i] = this.imageData.data[i + 1] = this.imageData.data[i + 2] = gray;
      } else if (ttt === 1 || ttt === 0) { // RGB (1) or default (0)
        this.imageData.data[i] = readChannel(c);
        this.imageData.data[i + 1] = readChannel(c + bytesPerChannel);
        this.imageData.data[i + 2] = readChannel(c + bytesPerChannel * 2);
        c += bytesPerChannel * 3;
      } else if (ttt === 3) { // RGBW
        const r = readChannel(c);
        const g = readChannel(c + bytesPerChannel);
        const b = readChannel(c + bytesPerChannel * 2);
        const w = readChannel(c + bytesPerChannel * 3);
        c += bytesPerChannel * 4;
        this.imageData.data[i] = Math.min(255, r + w);
        this.imageData.data[i + 1] = Math.min(255, g + w);
        this.imageData.data[i + 2] = Math.min(255, b + w);
      } else if (ttt === 2) { // HSL
        const rgb = hslToRgb(
          readChannel(c) / 255,
          readChannel(c + bytesPerChannel) / 255,
          readChannel(c + bytesPerChannel * 2) / 255
        );
        c += bytesPerChannel * 3;
        this.imageData.data[i] = rgb[0];
        this.imageData.data[i + 1] = rgb[1];
        this.imageData.data[i + 2] = rgb[2];
      } else { // unsupported
        c += bytesPerChannel * 3;
      }

      this.imageData.data[i + 3] = 255; // alpha
    }

    if (push) {
      this.ctx.putImageData(this.imageData, 0, 0);
    }
  }
}
