#extension GL_OES_standard_derivatives : enable

#ifdef GL_ES
precision mediump float;
#endif

#include "data/common.glsl"

varying vec4 v_position;
varying vec4 v_normal;
varying vec2 v_texcoord;
varying vec4 v_color;

uniform mat4 u_projectionMatrix;
uniform mat4 u_modelViewMatrix;
uniform mat4 u_normalMatrix;
uniform vec2 u_resolution;
uniform float u_time;

uniform sampler2D u_tex0; // base color
uniform sampler2D u_tex1; // skybox / environment
uniform sampler2D u_tex2; // normal map
uniform sampler2D u_tex3; // metallic-roughness packed map

#if defined(VERTEX)

attribute vec4 a_position;
attribute vec4 a_normal;
attribute vec2 a_texcoord;
attribute vec4 a_color;

void main(void) {
    vec3 pos = a_position.xyz;

    v_position = u_projectionMatrix * u_modelViewMatrix * vec4(pos, a_position.w);
    v_normal = u_normalMatrix * a_normal;
    v_texcoord = a_texcoord;
    v_color = a_color;

    gl_Position = v_position;
}

// void main(void) {
//     vec3 pos = a_position.xyz;
//     vec3 nrm = normalize(a_normal.xyz);

//     // vertex deformation
//     float wave1 = sin(pos.y * 7.0 + u_time * 2.0) * 0.03;
//     float wave2 = sin(pos.x * 5.0 + u_time * 1.5) * 0.02;
//     float deform = wave1 + wave2;

//     // move vertex along normal direction
//     pos += nrm * deform;

//     v_position = u_projectionMatrix * u_modelViewMatrix * vec4(pos, a_position.w);
//     v_normal = u_normalMatrix * vec4(nrm, 0.0);
//     v_texcoord = a_texcoord;
//     v_color = a_color;

//     gl_Position = v_position;
// }

#else

uniform vec2 u_mouse;
uniform vec2 u_pos;


float fresnelFunc(vec3 viewDir, vec3 normal, float ior) {
    float cosTheta = dot(viewDir, normal);
    float r0 = pow((1.0 - ior) / (1.0 + ior), 2.0);
    return r0 + (1.0 - r0) * pow(1.0 - cosTheta, 5.0);
}

vec3 rembrandtPhong(vec3 p, vec3 n, vec3 v) {
    vec3 ambient = vec3(0.02, 0.02, 0.01);
    vec3 light_pos = vec3(3.0, 2.0, 1.0);
    vec3 light_col = vec3(1.0, 0.6, 0.4);
    vec3 l = normalize(light_pos - p);
    vec3 r = normalize(reflect(-l, n));
    float shininess = 5.5;
    vec3 diffuse = max(dot(l, n), 0.0) * light_col;
    vec3 specular = pow(max(dot(r, v), 0.01), shininess) * light_col * 0.3;
    return ambient + diffuse + specular;
}

vec3 phongShading(vec3 baseColor, vec3 p, vec3 normal, vec3 v) {
    vec3 lightPos = vec3(2.0, 3.0, 2.0);
    vec3 lightColor = vec3(1.0);
    vec3 ambient = 0.8 * baseColor;
    vec3 lightDir = normalize(lightPos - p);
    vec3 diffuse = max(dot(normal, lightDir), 0.0) * baseColor * lightColor;
    vec3 reflectDir = reflect(-lightDir, normal);
    vec3 specular = pow(max(dot(v, reflectDir), 0.5), 32.0) * lightColor;
    return ambient + diffuse + specular;
}

mat3 cotangentFrame(vec3 N, vec3 p, vec2 uv) {
    vec3 dp1 = dFdx(p);
    vec3 dp2 = dFdy(p);
    vec2 duv1 = dFdx(uv);
    vec2 duv2 = dFdy(uv);

    vec3 dp2perp = cross(dp2, N);
    vec3 dp1perp = cross(N, dp1);
    vec3 T = dp2perp * duv1.x + dp1perp * duv2.x;
    vec3 B = dp2perp * duv1.y + dp1perp * duv2.y;

    float invmax = inversesqrt(max(dot(T, T), dot(B, B)));
    return mat3(T * invmax, B * invmax, N);
}

vec3 getMappedNormal(vec3 geomNormal, vec3 p, vec2 uv) {
    vec3 mapN = texture2D(u_tex2, uv).xyz * 2.0 - 1.0;
    mat3 TBN = cotangentFrame(geomNormal, p, uv);
    return normalize(TBN * mapN);
}

void main() {
    vec2 uv = v_texcoord;
    vec3 normal = normalize(v_normal.xyz);
    vec3 p = v_position.xyz;
    vec3 v = normalize(-p);

    vec3 color = normal;

    // ===== MODE INDEX LIST =====
    //  0 = texture
    //  1 = vertex color
    //  2 = normal
    //  3 = uv
    //  4 = position
    //  5 = view direction
    //  6 = absolute normal
    //  7 = absolute view direction
    //  8 = position procedural pattern
    //  9 = depth spectrum
    // 10 = reflection
    // 11 = refraction + reflection fresnel
    // 12 = view-angle procedural
    // 13 = phong shading
    // 14 = rembrandt
    // 15 = toon shading
    // 16 = advanced toon shading
    // 17 = gooch shading
    // 18 = vibrant gooch shading
    // 19 = gooch + black outline
    // 20 = soap bubble
    // 21 = tiger stripes
    // 22 = dragonfly wing
    // 23 = living water
    // 24 = trapped scaffolding crystal
    // 25 = Pearlescent
    // 26 = Realism
    // 27 = dissolve
    // 28 = Blinn-Phong shading

    int index = 28;

    if (index == 0) {
        color = texture2D(u_tex0, uv).rgb;
    }
    else if (index == 1) {
        color = v_color.rgb;
    }
    else if (index == 2) {
        color = normal;
    }
    else if (index == 3) {
        color = uv.xyx;
    }
    else if (index == 4) {
        color = v_position.xyz;
    }
    else if (index == 5) {
        color = v;
    }
    else if (index == 6) {
        color = abs(normal);
    }
    else if (index == 7) {
        color = abs(v);
    }
    else if (index == 8) {
        color = vec3(abs(p.xy / 4.0), p.z / 20.0);
    }
    else if (index == 9) {
        float depth = smoothstep(5.0, 8.0, v_position.z);
        color = spectrum(depth);
    }
    else if (index == 10) {
        vec3 reflectDir = reflect(-v, normal);
        color = texture2D(u_tex1, SphereMap(reflectDir)).rgb;
    }
    else if (index == 11) {
        float ior = 0.1;
        vec3 refractDir = refract(-v, normal, 1.0 / ior);
        vec3 reflectDir = reflect(-v, normal);
        vec3 refractColor = texture2D(u_tex0, SphereMap(refractDir)).rgb;
        vec3 reflectColor = texture2D(u_tex1, SphereMap(reflectDir)).rgb;
        float fresnelTerm = pow(1.0 - dot(v, normal), 5.0);
        color = mix(refractColor, reflectColor, fresnelTerm);
    }
    else if (index == 12) {
        float VdotN = smoothstep(-0.8, 0.5, dot(v, normal));
        color = vec3(VdotN);
    }
    else if (index == 13) {
        color = phongShading(texture2D(u_tex0, uv).rgb, p, normal, v);
    }
    else if (index == 14) {
        color = rembrandtPhong(p, normal, v);

        float gray = dot(color, vec3(0.299, 0.587, 0.114));
        color = mix(color, vec3(gray), 0.3);
        color.r *= 3.3;
        color.g *= 1.9;
        color.b *= 0.8;
        color += (sin(uv.x * 800.0) * sin(uv.y * 800.0)) * 0.02;

        float vignette = 1.0 - length(uv - 0.5) * 0.8;
        vignette = clamp(vignette, 0.0, 1.0);
        color *= vignette;
    }
    else if (index == 15) {
        vec3 lightDir = normalize(vec3(2.0, 3.0, 2.0));
        vec3 baseColor = texture2D(u_tex0, uv).rgb;

        float intensity = max(dot(normal, lightDir), 0.0);
        float toonDiff;

        if (intensity > 0.95) toonDiff = 1.0;
        else if (intensity > 0.5) toonDiff = 0.6;
        else if (intensity > 0.25) toonDiff = 0.3;
        else toonDiff = 0.1;

        vec3 reflectDir = reflect(-lightDir, normal);
        float spec = pow(max(dot(v, reflectDir), 0.0), 32.0);
        float toonSpec = step(0.5, spec);

        color = baseColor * toonDiff + vec3(1.0) * toonSpec;
    }
    else if (index == 16) {
        vec3 toonNormal = normalize(v_normal.xyz);
        vec3 lightDir = normalize(vec3(2.0, 3.0, 2.0));
        vec3 viewDir = normalize(-v_position.xyz);
        vec3 safeViewDir = vec3(0.0, 0.0, 1.0);

        vec3 baseColor = texture2D(u_tex0, uv).rgb;

        float NdotL = max(dot(toonNormal, lightDir), 0.0);
        float toonDiff =
            smoothstep(0.0, 0.05, NdotL) * 0.4 +
            smoothstep(0.5, 0.55, NdotL) * 0.5 +
            0.1;

        vec3 halfDir = normalize(lightDir + viewDir);
        float NdotH = max(dot(toonNormal, halfDir), 0.0);
        float spec = pow(NdotH, 64.0);
        float toonSpec = smoothstep(0.1, 0.15, spec);

        float rimParam = 1.0 - max(dot(viewDir, toonNormal), 0.0);
        float rimAmount = smoothstep(0.65, 0.8, rimParam);

        vec3 rimColor = vec3(0.0, 0.8, 1.0);
        float rimIntensity = rimAmount * pow(1.0 - NdotL, 3.0);

        vec3 litColor = (baseColor * toonDiff) + (vec3(1.0) * toonSpec) + (rimColor * rimIntensity);

        float VdotN_safe = max(dot(safeViewDir, toonNormal), 0.0);
        float outline = smoothstep(0.2, 0.25, VdotN_safe);
        vec3 outlineColor = vec3(0.05, 0.05, 0.08);

        color = mix(outlineColor, litColor, outline);

        gl_FragColor = vec4(color, 1.0);
        return;
    }
    else if (index == 17) {
        vec3 lightDir = normalize(vec3(2.0, 3.0, 2.0));
        vec3 baseColor = texture2D(u_tex0, uv).rgb;

        vec3 coolColor = vec3(0.0, 0.0, 0.55) + 0.25 * baseColor;
        vec3 warmColor = vec3(0.3, 0.3, 0.0) + 0.25 * baseColor;

        float NdotL = dot(normal, lightDir);
        float goochWeight = (1.0 + NdotL) * 0.5;

        vec3 reflectDir = reflect(-lightDir, normal);
        float spec = pow(max(dot(v, reflectDir), 0.0), 32.0);

        color = mix(coolColor, warmColor, goochWeight) + vec3(1.0) * spec * 0.5;
    }
    else if (index == 18) {
        vec3 lightDir = normalize(vec3(1.0, 2.0, 1.0));
        vec3 baseColor = texture2D(u_tex0, uv).rgb;

        vec3 coolColor = vec3(0.0, 0.3, 0.9) + (0.15 * baseColor);
        vec3 warmColor = vec3(1.0, 0.4, 0.1) + (0.3 * baseColor);

        float NdotL = dot(normal, lightDir);
        float goochWeight = (1.0 + NdotL) * 0.5;
        vec3 diffuseGooch = mix(coolColor, warmColor, goochWeight);

        vec3 safeViewDir = vec3(0.0, 0.0, 1.0);

        vec3 reflectDir = reflect(-lightDir, normal);
        float spec = pow(max(dot(safeViewDir, reflectDir), 0.0), 32.0);
        float crispSpec = smoothstep(0.4, 0.45, spec);

        float rim = 1.0 - max(dot(safeViewDir, normal), 0.0);
        float outline = smoothstep(0.85, 0.9, rim);
        vec3 outlineColor = vec3(0.1, 0.0, 0.2);

        color = mix(diffuseGooch, outlineColor, outline) + (vec3(1.0) * crispSpec * 0.8);
    }
    else if (index == 19) {
        vec3 goochNormal = normalize(v_normal.xyz);
        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        vec3 lightDir = normalize(vec3(1.0, 2.0, 1.5));

        vec3 coolColor = vec3(0.2, 0.2, 0.6);
        vec3 warmColor = vec3(0.9, 0.7, 0.2);

        float NdotL = dot(goochNormal, lightDir);
        float goochWeight = (1.0 + NdotL) * 0.5;
        vec3 baseGooch = mix(coolColor, warmColor, goochWeight);

        vec3 reflectDir = reflect(-lightDir, goochNormal);
        float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32.0);
        float hardSpec = smoothstep(0.45, 0.5, spec);
        baseGooch += vec3(1.0) * hardSpec * 0.8;

        float VdotN = max(dot(viewDir, goochNormal), 0.0);
        float outline = smoothstep(0.2, 0.25, VdotN);

        color = baseGooch * outline;

        gl_FragColor = vec4(color, 1.0);
        return;
    }
    else if (index == 20) {
        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        float VdotN = max(dot(viewDir, normal), 0.0);

        float fresnelTerm = pow(1.0 - VdotN, 2.5);

        vec3 a = vec3(0.5, 0.5, 0.5);
        vec3 b = vec3(0.5, 0.5, 0.5);
        vec3 c = vec3(1.0, 1.0, 1.0);
        vec3 d = vec3(0.67, 0.33, 0.00);
        vec3 iridescence = a + b * cos(6.28318 * (c * (VdotN * 3.0) + d));
        iridescence *= fresnelTerm;

        vec3 reflectDir = reflect(-viewDir, normal);
        vec3 envColor = texture2D(u_tex1, SphereMap(reflectDir)).rgb;
        envColor *= (fresnelTerm * 0.8);

        vec3 light1 = normalize(vec3(2.0, 3.0, 5.0));
        vec3 light2 = normalize(vec3(-3.0, -1.0, 4.0));
        vec3 half1 = normalize(light1 + viewDir);
        vec3 half2 = normalize(light2 + viewDir);
        float spec1 = pow(max(dot(normal, half1), 0.0), 256.0);
        float spec2 = pow(max(dot(normal, half2), 0.0), 128.0);

        color = envColor + iridescence + (vec3(1.0) * spec1) + (vec3(0.8, 0.9, 1.0) * spec2);

        float alpha = clamp(fresnelTerm + spec1 + spec2 + 0.1, 0.0, 1.0);

        gl_FragColor = vec4(color, alpha);
        return;
    }
    else if (index == 21) {
        vec3 tigerOrange = vec3(1.0, 0.45, 0.1);
        vec3 tigerBlack = vec3(0.1, 0.1, 0.12);
        vec3 tigerWhite = vec3(0.95, 0.95, 0.9);

        float wave = sin(p.y * 15.0 + sin(p.x * 10.0) * 2.0);

        float distortion = fract(sin(dot(p.xyz, vec3(12.9898, 78.233, 45.543))) * 43758.5453);
        wave += (distortion - 0.5) * 1.5;

        vec3 albedo;
        if (wave > 0.5) {
            albedo = tigerBlack;
        } else if (wave < -0.8) {
            albedo = tigerWhite;
        } else {
            albedo = tigerOrange;
        }

        vec3 lightDir = normalize(vec3(2.0, 3.0, 2.0));
        float diff = max(dot(normal, lightDir), 0.0);
        float toonLight = smoothstep(0.4, 0.45, diff) * 0.7 + 0.3;

        color = albedo * toonLight;

        gl_FragColor = vec4(color, 1.0);
        return;
    }
    else if (index == 22) {
        vec3 deepTeal = vec3(0.0, 0.3, 0.4);
        vec3 bioGreen = vec3(0.2, 0.8, 0.4);
        vec3 vividViolet = vec3(0.6, 0.2, 0.8);
        vec3 delicateGold = vec3(0.9, 0.8, 0.4);

        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        float VdotN = abs(dot(viewDir, normal));

        float cellNoise = fract(sin(dot(uv * 15.0, vec2(12.9898, 78.233))) * 43758.5453);
        float veinEdge = smoothstep(0.85, 0.9, cellNoise);

        vec3 baseColor = mix(vividViolet, bioGreen, VdotN);
        baseColor = mix(deepTeal, baseColor, smoothstep(0.0, 0.5, VdotN));

        color = mix(baseColor, delicateGold, veinEdge);

        vec3 lightDir = normalize(vec3(1.0, 5.0, 2.0));
        vec3 halfDir = normalize(lightDir + viewDir);
        float spec = pow(max(dot(normal, halfDir), 0.0), 32.0);

        color += delicateGold * spec * 0.5;

        float alpha = clamp(VdotN + veinEdge + 0.2, 0.0, 1.0);
        gl_FragColor = vec4(color, alpha);
        return;
    }
    else if (index == 23) {
        vec3 deepOcean = vec3(0.0, 0.1, 0.3);
        vec3 shallowCyan = vec3(0.0, 0.6, 0.8);
        vec3 causticWhite = vec3(0.9, 1.0, 1.0);

        float wave1 = 1.0 - abs(sin(p.x * 12.0 + u_time * 2.0 + p.z * 4.0));
        float wave2 = 1.0 - abs(sin(p.y * 15.0 - u_time * 1.5 + p.x * 5.0));

        float caustics = pow(wave1 * wave2, 2.0);

        vec3 distortedNormal = normalize(normal + vec3(wave1, wave2, wave1) * 0.15);

        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        float VdotN = max(dot(viewDir, distortedNormal), 0.0);
        float fresnelTerm = pow(1.0 - VdotN, 3.0);

        vec3 waterColor = mix(shallowCyan, deepOcean, VdotN);
        waterColor += causticWhite * caustics * 1.5;

        vec3 reflectDir = reflect(-viewDir, distortedNormal);
        vec3 envColor = texture2D(u_tex1, SphereMap(reflectDir)).rgb;

        vec3 lightDir = normalize(vec3(2.0, 5.0, 3.0));
        vec3 halfDir = normalize(lightDir + viewDir);
        float spec = pow(max(dot(distortedNormal, halfDir), 0.0), 64.0);

        color = (waterColor * 0.7) + (envColor * fresnelTerm) + (causticWhite * spec);

        float alpha = clamp(fresnelTerm + caustics + spec + 0.2, 0.0, 1.0);

        gl_FragColor = vec4(color, alpha);
        return;
    }
    else if (index == 24) {
        vec3 viewDir = vec3(0.0, 0.0, 1.0);

        float volumeGridSize = 25.0;
        vec3 Volume_P = p * volumeGridSize;
        float form_Distort = length(p);
        Volume_P *= (1.0 - form_Distort * 0.15);

        vec3 gridFract = fract(Volume_P);
        vec3 dGrid = fwidth(Volume_P);
        vec3 lines = smoothstep(0.4 - dGrid, 0.4 + dGrid, gridFract);

        float scaffoldingValue = min(lines.x, lines.y);
        scaffoldingValue = min(scaffoldingValue, lines.z);

        float points = length(max(gridFract - 0.5, 0.0));
        points = smoothstep(0.08, 0.0, points);
        scaffoldingValue += points;
        scaffoldingValue = clamp(scaffoldingValue, 0.0, 1.0);

        float ior = 1.5;
        vec3 refractDir = refract(-viewDir, normal, 1.0 / ior);

        vec3 Refracted_P = (p + refractDir * 0.1) * volumeGridSize;
        Refracted_P *= (1.0 - form_Distort * 0.15);
        vec3 rGridFract = fract(Refracted_P);
        vec3 rdGrid = fwidth(Refracted_P);
        vec3 rLines = smoothstep(0.4 - rdGrid, 0.4 + rdGrid, rGridFract);
        float rScaffolding = min(rLines.x, rLines.y);
        rScaffolding = min(rScaffolding, rLines.z);
        rScaffolding = mix(rScaffolding, rScaffolding * 0.7, form_Distort);

        scaffoldingValue = mix(scaffoldingValue, rScaffolding * 1.5, form_Distort);
        scaffoldingValue = clamp(scaffoldingValue, 0.0, 1.0);

        vec3 a = vec3(0.5, 0.5, 0.5);
        vec3 b = vec3(0.5, 0.5, 0.5);
        vec3 c = vec3(1.0, 1.0, 1.0);
        vec3 d = vec3(0.00, 0.33, 0.67);
        vec3 rainbowColor = a + b * cos(6.28318 * (c * (p.y * 2.0 + p.z) + d + u_time * 0.2));

        vec3 scaffoldColor = rainbowColor;
        vec3 scaffoldGlow = rainbowColor * 1.5;
        scaffoldColor = mix(scaffoldColor, scaffoldColor + scaffoldGlow, points);

        vec3 reflectDir = reflect(-viewDir, normal);
        vec3 envColor = texture2D(u_tex1, SphereMap(reflectDir)).rgb;

        float VdotN = max(dot(viewDir, normal), 0.0);
        float fresnelTerm = pow(1.0 - VdotN, 2.5);

        vec3 specColor = vec3(1.0);
        float spec = pow(max(dot(normal, normalize(vec3(5.0, 5.0, 2.0) + viewDir)), 0.0), 256.0);

        vec3 holoCore = a + b * cos(6.28318 * (c * (VdotN * 2.0) + vec3(0.67, 0.33, 0.00)));
        vec3 clearBase = mix(vec3(0.05), envColor, fresnelTerm);
        clearBase = mix(clearBase, clearBase + holoCore * 0.2, smoothstep(0.0, 0.5, 1.0 - form_Distort));

        color = clearBase + (scaffoldColor * scaffoldingValue) + (specColor * spec);
        color *= mix(vec3(1.0), holoCore, fresnelTerm * 0.5);

        float alpha = clamp(fresnelTerm + spec + scaffoldingValue * 0.7 + 0.1, 0.0, 1.0);

        gl_FragColor = vec4(color, alpha);
        return;
    }

    else if (index == 25) {
       
        vec3 baseColor = vec3(0.95, 0.9, 0.85); // Creamy base
        vec3 viewDir = vec3(0.0, 0.0, 1.0);
        float VdotN = max(dot(viewDir, normal), 0.0);
        
        
        float shift = VdotN * 5.0 + u_time * 0.2;
        vec3 sheen = 0.1 * vec3(cos(shift), cos(shift + 2.0), cos(shift + 4.0));
        
        
        float softSpec = pow(VdotN, 10.0) * 0.4;
        float hardSpec = pow(VdotN, 128.0) * 0.8;
        
        color = baseColor + sheen + (vec3(2.0) * (softSpec + hardSpec));
        gl_FragColor = vec4(color, 1.0);
        return;
    }

    else if (index == 26) {
    vec3 baseTexture = texture2D(u_tex0, uv).rgb;
    
    // 1. Define Light Positions (adjust these to move the 'dots' of light)
    vec3 lightPos1 = vec3(3.0, 2.0, 5.0);   // Key Light (Front-Right)
    vec3 lightPos2 = vec3(-4.0, -2.0, 3.0); // Fill Light (Left-Back)
    
    vec3 lCol1 = vec3(1.0, 0.9, 0.8); // Warm white
    vec3 lCol2 = vec3(0.4, 0.6, 1.0); // Cool blue shadow-fill

    // 2. Global Ambient (This prevents the "too dark" look)
    // 0.05 is a subtle 5% baseline visibility
    vec3 ambient = vec3(0.05, 0.05, 0.08) * baseTexture;
    vec3 totalDiffuse = vec3(0.0);
    vec3 totalSpecular = vec3(0.0);

    // Light 1 Calculation
    vec3 L1 = normalize(lightPos1 - p);
    float diff1 = max(dot(normal, L1), 0.0);
    vec3 R1 = reflect(-L1, normal);
    float spec1 = pow(max(dot(R1, v), 0.0), 64.0); // Sharp sparkle
    totalDiffuse += lCol1 * diff1;
    totalSpecular += lCol1 * spec1;

    // Light 2 Calculation
    vec3 L2 = normalize(lightPos2 - p);
    float diff2 = max(dot(normal, L2), 0.0);
    vec3 R2 = reflect(-L2, normal);
    float spec2 = pow(max(dot(R2, v), 0.0), 32.0); // Softer sparkle
    totalDiffuse += lCol2 * diff2;
    totalSpecular += lCol2 * spec2;

    // 3. Final Composition
    // (Texture * Lighting) + Reflections
    color = ambient + (baseTexture * totalDiffuse) + (totalSpecular * 0.8);

    gl_FragColor = vec4(color, 1.0);
    return;
}

else if (index == 27) {
    // 1. Time-based threshold (moves from 0.0 to 1.0 and back)
    // Adjust 0.5 to change the speed of the "evaporation"
    float threshold = sin(u_time * 0.8) * 0.5 + 0.5;

    // 2. High-frequency 3D Noise 
    // We use all three coordinates (p.x, p.y, p.z) so the holes appear everywhere
    float noise = fract(sin(dot(p.xyz, vec3(12.989, 78.233, 45.164))) * 43758.545);
    
    // To make the dissolve look "chunky" rather than like static, 
    // we mix the noise with a sine wave based on position
    float pattern = noise * 0.5 + 0.5 * sin(p.x * 20.0) * cos(p.z * 20.0);

    // 3. The Full Body Discard
    if (pattern < threshold) {
        discard;
    }

    // 4. Emissive "Energy" Edge
    // This creates that bright blue glowing border where it's disappearing
    float edgeWidth = 0.08;
    float edgeMask = smoothstep(threshold + edgeWidth, threshold, pattern);
    
    vec3 baseColor = vec3(0.0, 0.2, 0.5); // Deep sea blue
    vec3 glowColor = vec3(0.6, 0.9, 1.0) * 3.0; // Intense blue/white glow

    // Basic lighting for the remaining "solid" parts
    vec3 lightDir = normalize(vec3(1.0, 2.0, 1.0));
    float diff = max(dot(normal, lightDir), 0.3);
    
    // Mix the shaded blue with the glowing edge
    color = mix(baseColor * diff, glowColor, edgeMask);

    gl_FragColor = vec4(color, 1.0);
    return;
}

else if (index == 28) {
    vec3 N = normalize(normal);
    vec3 P = v_position.xyz;     // view-space position
    vec3 V = normalize(-P);      // view direction
    vec3 baseTex = texture2D(u_tex0, v_texcoord).rgb;

    // --------------------------------------------------
    // 0) Cursor -> light control
    // --------------------------------------------------
    vec2 mouse = u_mouse / u_resolution;   // 0..1
    mouse = mouse * 2.0 - 1.0;             // -1..1
    mouse.y = -mouse.y;

    // Cursor-controlled point light
    vec3 cursorLightPos = vec3(mouse.x * 4.0, mouse.y * 3.0, 3.0);

    // Cursor-controlled sunlight direction
    vec3 sunDir = normalize(vec3(mouse.x * 0.9, mouse.y * 0.6, 0.8));

    // Optional: cursor moves the wide light band up/down
    float bandCenter = mouse.y * 0.5;

    // --------------------------------------------------
    // 1) Glass / environment
    // --------------------------------------------------
    float iorR = 1.08;
    float iorG = 1.10;
    float iorB = 1.12;

    vec3 refrR = refract(-V, N, 1.0 / iorR);
    vec3 refrG = refract(-V, N, 1.0 / iorG);
    vec3 refrB = refract(-V, N, 1.0 / iorB);

    vec3 refrColor = vec3(
        texture2D(u_tex1, SphereMap(refrR)).r,
        texture2D(u_tex1, SphereMap(refrG)).g,
        texture2D(u_tex1, SphereMap(refrB)).b
    );

    vec3 reflectColor = texture2D(u_tex1, SphereMap(reflect(-V, N))).rgb;

    float fresnel = pow(1.0 - max(dot(V, N), 0.0), 3.0);

    // --------------------------------------------------
    // 2) Main warm key light
    // --------------------------------------------------
    vec3 keyLightPos = vec3(2.5, 2.0, 3.5);
    vec3 L1 = normalize(keyLightPos - P);
    float d1 = length(keyLightPos - P);
    float att1 = 1.0 / (1.0 + 0.10 * d1 + 0.03 * d1 * d1);

    float diff1 = max(dot(N, L1), 0.0);

    vec3 H1 = normalize(L1 + V);
    float spec1 = pow(max(dot(N, H1), 0.0), 12.0);

    vec3 keyColor = vec3(1.0, 0.95, 0.90);

    // --------------------------------------------------
    // 3) Cursor-controlled broad sunlight
    // --------------------------------------------------
    float sunDiff = max(dot(N, sunDir), 0.0);

    vec3 Hsun = normalize(sunDir + V);
    float sunSpec = pow(max(dot(N, Hsun), 0.0), 10.0);

    vec3 sunColor = vec3(1.0, 0.96, 0.88);

    // --------------------------------------------------
    // 4) Cursor-controlled point light
    // --------------------------------------------------
    vec3 Lcursor = normalize(cursorLightPos - P);
    float dCursor = length(cursorLightPos - P);
    float attCursor = 1.0 / (1.0 + 0.10 * dCursor + 0.03 * dCursor * dCursor);

    float diffCursor = max(dot(N, Lcursor), 0.0);

    vec3 Hcursor = normalize(Lcursor + V);
    float specCursor = pow(max(dot(N, Hcursor), 0.0), 16.0);

    vec3 cursorColor = vec3(1.0, 0.97, 0.92);

    // --------------------------------------------------
    // 5) Wide sunlight band
    // --------------------------------------------------
    float bandWidth = 0.55;

    // If p is not defined in your shader, replace p.y with v_position.y
    float yDist = (p.y - bandCenter) / bandWidth;
    float bandMask = exp(-yDist * yDist * 0.9);

    float grazing = pow(1.0 - max(dot(V, N), 0.0), 1.5);

    vec3 wideSunBand =
        (sunColor * (0.35 + 0.65 * sunDiff) + reflectColor * 0.35)
        * bandMask
        * (0.45 + 0.55 * grazing);

    vec3 sunSpecular = sunColor * sunSpec * bandMask * 0.8;

    // --------------------------------------------------
    // 6) Material base
    // --------------------------------------------------
    vec3 glassBase = mix(refrColor * baseTex, reflectColor, 0.25 + 0.55 * fresnel);

    vec3 ambient = baseTex * 0.12;

    vec3 diffuse =
          baseTex * keyColor    * diff1      * att1      * 0.55
        + baseTex * sunColor    * sunDiff                * 0.28
        + baseTex * cursorColor * diffCursor * attCursor * 0.35;

    vec3 specular =
          keyColor    * spec1      * att1      * 0.65
        + sunColor    * sunSpec                * 0.15
        + cursorColor * specCursor * attCursor * 0.45;

    vec3 rim = reflectColor * fresnel * 0.35;

    // --------------------------------------------------
    // 7) Final
    // --------------------------------------------------
    color = glassBase * 0.78
          + ambient
          + diffuse
          + specular
          + wideSunBand
          + sunSpecular
          + rim;

    gl_FragColor = vec4(color, 1.0);
    return;
}

 
    gl_FragColor = vec4(color, 1.0);
}

#endif