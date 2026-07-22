#version 440

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float value;
    float time;
    vec4  successColor;
    vec4  criticalColor;
} ubuf;

const float PI  = 3.14159265358979;
const float PI2 = 6.28318530717959;

// ── HSL helpers ───────────────────────────────────────────────────────────────

vec3 rgb2hsl(vec3 c) {
    float mx = max(c.r, max(c.g, c.b));
    float mn = min(c.r, min(c.g, c.b));
    float l  = (mx + mn) * 0.5;
    if (mx == mn) return vec3(0.0, 0.0, l);
    float d = mx - mn;
    float s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn);
    float h;
    if      (mx == c.r) h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
    else if (mx == c.g) h = (c.b - c.r) / d + 2.0;
    else                h = (c.r - c.g) / d + 4.0;
    return vec3(h / 6.0, s, l);
}

float _hue2c(float p, float q, float t) {
    t = fract(t);
    if (t < 1.0/6.0) return p + (q - p) * 6.0 * t;
    if (t < 0.5)     return q;
    if (t < 2.0/3.0) return p + (q - p) * (2.0/3.0 - t) * 6.0;
    return p;
}

vec3 hsl2rgb(vec3 hsl) {
    if (hsl.y == 0.0) return vec3(hsl.z);
    float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
    float p = 2.0 * hsl.z - q;
    return vec3(
        _hue2c(p, q, hsl.x + 1.0/3.0),
        _hue2c(p, q, hsl.x),
        _hue2c(p, q, hsl.x - 1.0/3.0)
    );
}

// Interpolate hue from successColor to criticalColor (shortest path on wheel)
vec3 metricColor(float t) {
    vec3 hslA = rgb2hsl(ubuf.successColor.rgb);
    vec3 hslB = rgb2hsl(ubuf.criticalColor.rgb);
    float diff = hslB.x - hslA.x;
    if (abs(diff) > 0.5) diff -= sign(diff);
    float h = fract(hslA.x + diff * t);
    return hsl2rgb(vec3(h, hslA.y, hslA.z));
}

// ── Main ──────────────────────────────────────────────────────────────────────

void main() {
    // Center UV: -0.5 to +0.5
    vec2  uv = qt_TexCoord0 - vec2(0.5);
    float v  = clamp(ubuf.value, 0.0, 1.0);
    float t  = ubuf.time;

    const float CIRCLE_R    = 0.33;
    const float TRAIL_ARC   = PI * 0.5;   // 25 % of circumference
    const float DOT_R_MIN   = 0.02;
    const float DOT_R_MAX   = CIRCLE_R * 0.15;
    const float OSC_AMP_MAX = 0.14;
    const float OSC_FREQ    = 8.0;        // radial wiggle cycles per full circle

    // Dot angle: clockwise from top, one lap = 30 s
    // fract() keeps the argument small for float precision
    float dotAngle = -PI * 0.5 + fract(t / 30.0) * PI2;

    // Dot radius: purely value-driven, no breathing
    float dotR = mix(DOT_R_MIN, DOT_R_MAX, v);

    // Oscillation: amplitude and speed loosely tied to value
    float oscAmp   = mix(0.0, OSC_AMP_MAX, v);
    float oscSpeed = mix(0.5, 2.0, v);

    // Pixel polar coords
    float pixLen   = length(uv);
    float pixAngle = atan(uv.y, uv.x);

    // ── DOT ───────────────────────────────────────────────────────────────────
    float dotOsc = oscAmp * sin(OSC_FREQ * dotAngle + fract(t * oscSpeed) * PI2);
    vec2  dotPos = vec2(cos(dotAngle), sin(dotAngle)) * (CIRCLE_R + dotOsc);
    float dDot   = length(uv - dotPos);
    float aaD    = fwidth(dDot);
    float dotA   = 1.0 - smoothstep(dotR - aaD, dotR + aaD, dDot);

    // ── TRAIL ─────────────────────────────────────────────────────────────────
    // Angular offset behind dot in clockwise direction → [0, 2π)
    float angOff = mod(dotAngle - pixAngle, PI2);
    float trailT = angOff / TRAIL_ARC;                       // 0 = head, 1 = tail
    float onT    = step(0.0, trailT) * (1.0 - step(1.0, trailT));

    // Displaced radius at pixel's angular position
    float trailR = CIRCLE_R + oscAmp * sin(OSC_FREQ * pixAngle + fract(t * oscSpeed) * PI2);

    // Width tapers: dotR at head, 0 at tail
    float trailW  = dotR * (1.0 - trailT);
    float dTrail  = abs(pixLen - trailR);
    float aaT     = fwidth(dTrail);
    float trailA  = onT * (1.0 - smoothstep(trailW - aaT, trailW + aaT, dTrail));
    trailA *= 1.0 - trailT * 0.5;   // fade opacity toward tail

    // ── Compose (premultiplied alpha for Qt Quick) ─────────────────────────────
    vec3  col   = metricColor(v);
    float alpha = max(dotA, trailA) * ubuf.qt_Opacity;
    fragColor   = vec4(col * alpha, alpha);
}
