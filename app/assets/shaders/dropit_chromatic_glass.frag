#include <flutter/runtime_effect.glsl>
precision highp float;

// Physical pixel dimensions of the active backdrop / target texture.
uniform vec2 u_resolution;
// Top-left of the glass lens inside the active backdrop surface, in physical px.
uniform vec2 u_lensOrigin;
// Width and height of the glass lens, in physical px.
uniform vec2 u_lensSize;
// x = cornerRadiusPx, y = refractionWidthPx, z = dispersionPx, w = magnification
uniform vec4 u_lensParams;
// x = refractionIndex, y = curvatureExponent, z = rimStrength, w = blurSigmaPx
uniform vec4 u_opticsParams;
// Deformed scale (scaleX, scaleY) for elastic hover/press/drag transitions.
uniform vec2 u_shapeScale;
// Inverse row-major 2x2 linear transform (default: identity 1, 0, 0, 1) and
// whether a custom non-identity transform is active.
uniform vec4 u_xformInv;

uniform sampler2D u_texture_input;

out vec4 fragColor;

float sdRoundedRect(vec2 p, vec2 halfExtents, float radius) {
  vec2 inner = max(halfExtents - vec2(radius), vec2(0.0));
  vec2 q = abs(p) - inner;
  return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

vec2 roundedRectNormal(vec2 p, vec2 halfExtents, float radius) {
  float eps = 1.0;
  float dx = sdRoundedRect(p + vec2(eps, 0.0), halfExtents, radius) -
             sdRoundedRect(p - vec2(eps, 0.0), halfExtents, radius);
  float dy = sdRoundedRect(p + vec2(0.0, eps), halfExtents, radius) -
             sdRoundedRect(p - vec2(0.0, eps), halfExtents, radius);
  vec2 grad = vec2(dx, dy);
  float len = length(grad);
  if (len < 1e-4) {
    return vec2(0.0, 1.0);
  }
  return grad / len;
}

vec4 sampleBackdropClamped(vec2 px, vec2 invRes, vec2 uvMin, vec2 uvMax) {
  vec2 uv = clamp(px * invRes, uvMin, uvMax);
  return texture(u_texture_input, uv);
}

void main() {
  vec2 fragPx = FlutterFragCoord().xy;
  vec2 safeScale = max(u_shapeScale, vec2(0.25));
  vec2 restSize = max(u_lensSize / safeScale, vec2(2.0));
  vec2 restHalf = restSize * 0.5;
  vec2 center = u_lensOrigin + u_lensSize * 0.5;

  // Map fragment offset into rest lens space so stretched capsules bend normals smoothly.
  vec2 deltaPx = fragPx - center;
  vec2 unxformed = vec2(
    u_xformInv.x * deltaPx.x + u_xformInv.y * deltaPx.y,
    u_xformInv.z * deltaPx.x + u_xformInv.w * deltaPx.y
  );
  vec2 restLocal = unxformed / safeScale;

  float cornerRadius = min(u_lensParams.x, min(restHalf.x, restHalf.y));
  float sdf = sdRoundedRect(restLocal, restHalf, cornerRadius);

  // Smooth 1px outer anti-aliasing.
  float coverage = 1.0 - smoothstep(-0.85, 0.65, sdf);
  if (coverage <= 0.002) {
    fragColor = vec4(0.0);
    return;
  }

  // Analytical outward surface normal in screen pixel coordinates.
  vec2 localNormal = roundedRectNormal(restLocal, restHalf, cornerRadius);
  // Transform normal direction inversely if ancestor matrix rotates/scales.
  vec2 normal = normalize(localNormal * safeScale + vec2(1e-5));

  float distInside = max(-sdf, 0.0);
  float bandWidth = max(u_lensParams.y, 1.0);
  float depthT = clamp(distInside / bandWidth, 0.0, 1.0);

  // Zero curvature in the interior, smooth optical curve toward the curved wall.
  float rimFactor = 1.0 - smoothstep(0.0, 1.0, depthT);
  float curvature = pow(rimFactor, max(u_opticsParams.y, 1.0));
  float cornerFactor = 1.0 + 0.30 * pow(clamp(2.0 * abs(normal.x * normal.y), 0.0, 1.0), 1.15);

  // Inverse center magnification + curved sidewall refraction along -normal.
  float mag = max(u_lensParams.w, 1.0);
  float magPull = (1.0 - 1.0 / mag) * (1.0 - curvature * 0.55);
  float etaDelta = max(u_opticsParams.x - 1.0, 0.0);
  float refractPull = curvature * etaDelta * bandWidth * 0.44;
  vec2 baseSamplePx = fragPx - normal * refractPull - deltaPx * magPull;

  vec2 safeRes = max(u_resolution, vec2(1.0));
  vec2 invRes = 1.0 / safeRes;
  vec2 uvMin = invRes * 0.5;
  vec2 uvMax = vec2(1.0) - uvMin;

  float dispPx = max(u_lensParams.z, 0.0);
  float chromaMask = smoothstep(0.03, 0.88, curvature);
  float effectiveDisp = dispPx * chromaMask * cornerFactor;

  float blurSigma = clamp(u_opticsParams.w, 0.0, 3.0);
  vec2 tangent = vec2(-normal.y, normal.x) * (blurSigma * 0.55);

  vec4 outSample;
  if (effectiveDisp <= 0.01) {
    vec4 centerTap = sampleBackdropClamped(baseSamplePx, invRes, uvMin, uvMax);
    if (blurSigma > 0.25) {
      vec4 tA = sampleBackdropClamped(baseSamplePx + tangent, invRes, uvMin, uvMax);
      vec4 tB = sampleBackdropClamped(baseSamplePx - tangent, invRes, uvMin, uvMax);
      outSample = centerTap * 0.50 + (tA + tB) * 0.25;
    } else {
      outSample = centerTap;
    }
  } else {
    // Geometry-aware RGB wavelength offsets aligned with the optical surface normal.
    vec2 redPos   = baseSamplePx + normal * effectiveDisp;
    vec2 amberPos = baseSamplePx + normal * (effectiveDisp * 0.48);
    vec2 greenPos = baseSamplePx;
    vec2 cyanPos  = baseSamplePx - normal * (effectiveDisp * 0.48);
    vec2 bluePos  = baseSamplePx - normal * effectiveDisp;

    vec4 sR = sampleBackdropClamped(redPos, invRes, uvMin, uvMax);
    vec4 sA = sampleBackdropClamped(amberPos, invRes, uvMin, uvMax);
    vec4 sG = sampleBackdropClamped(greenPos, invRes, uvMin, uvMax);
    vec4 sC = sampleBackdropClamped(cyanPos, invRes, uvMin, uvMax);
    vec4 sB = sampleBackdropClamped(bluePos, invRes, uvMin, uvMax);

    // Optional tangential softening only across the perpendicular axis so radial RGB stays vivid.
    if (blurSigma > 0.25) {
      vec4 rT = (sampleBackdropClamped(redPos + tangent, invRes, uvMin, uvMax) +
                 sampleBackdropClamped(redPos - tangent, invRes, uvMin, uvMax)) * 0.5;
      vec4 gT = (sampleBackdropClamped(greenPos + tangent, invRes, uvMin, uvMax) +
                 sampleBackdropClamped(greenPos - tangent, invRes, uvMin, uvMax)) * 0.5;
      vec4 bT = (sampleBackdropClamped(bluePos + tangent, invRes, uvMin, uvMax) +
                 sampleBackdropClamped(bluePos - tangent, invRes, uvMin, uvMax)) * 0.5;
      sR = mix(sR, rT, 0.35);
      sG = mix(sG, gT, 0.35);
      sB = mix(sB, bT, 0.35);
    }

    float redCh   = sR.r * 0.62 + sA.r * 0.38;
    float greenCh = sG.g * 0.76 + (sA.g + sC.g) * 0.12;
    float blueCh  = sB.b * 0.62 + sC.b * 0.38;
    float alpha   = max(max(sR.a, sG.a), max(sB.a, max(sA.a, sC.a)));
    outSample = vec4(clamp(vec3(redCh, greenCh, blueCh), 0.0, 1.0), alpha);
  }

  // Leave empty transparent desktop regions untouched on macOS NSWindow.
  if (outSample.a <= 0.002) {
    fragColor = vec4(0.0);
    return;
  }

  // Subtle neutral specular catchlight on top curved rim; color separation comes purely from backdrop RGB.
  float rimGlow = smoothstep(3.0, 0.2, distInside) * u_opticsParams.z * clamp(outSample.a, 0.0, 1.0);
  vec3 highlighted = outSample.rgb + vec3(rimGlow * 0.09);

  fragColor = vec4(clamp(highlighted, 0.0, 1.0), outSample.a) * coverage;
}
