#version 450

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4  accentColor;
    float rotationAngle;
    vec4  bars0;
    vec4  bars1;
    vec4  bars2;
    vec4  bars3;
};

float getBarVal(int idx) {
    vec4 b = idx < 4 ? bars0 : idx < 8 ? bars1 : idx < 12 ? bars2 : bars3;
    return b[idx % 4];
}

void main() {
    const float PI2       = 6.2831853;
    const float slotAngle = PI2 / 16.0;

    vec2  uv     = qt_TexCoord0 - vec2(0.5);
    float radius = length(uv) * 280.0;
    float angle  = mod(atan(uv.y, uv.x) + 1.5707963 - rotationAngle, PI2);

    int   segIndex = int(floor(angle / slotAngle));
    float val      = getBarVal(segIndex);

    float targetRadius = 95.0 + val * 32.0;
    float distToRing   = abs(radius - targetRadius);
    float halfThick    = 2.0 + val * 2.0;

    // Soft arc ends (approximate round caps)
    float localAngle = mod(angle, slotAngle) - slotAngle * 0.5;
    float arcEdge    = slotAngle * 0.03;
    float inArc      = 1.0 - smoothstep(slotAngle * 0.325 - arcEdge,
                                        slotAngle * 0.325 + arcEdge,
                                        abs(localAngle));

    // Core ring + glow halo
    float core = 1.0 - smoothstep(halfThick - 1.0, halfThick + 1.0, distToRing);
    float halo = (1.0 - smoothstep(0.0, halfThick * 5.0, distToRing)) * 0.35;

    float alpha = clamp(core + halo, 0.0, 1.0) * inArc * (0.45 + val * 0.40);

    fragColor = vec4(accentColor.rgb * alpha, alpha) * qt_Opacity;
}
