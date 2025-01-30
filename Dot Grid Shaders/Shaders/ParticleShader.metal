#include <metal_stdlib>
using namespace metal;

struct Particle {
    float2 position;    // Current x,y position of particle
    float2 velocity;    // Current movement speed and direction
    float life;         // Opacity/brightness of particle (0.0-1.0)
};

struct ParticleUniforms {
    float2 resolution;      // Screen size
    float time;            // Current time for animation
    float2 touchPosition;  // Touch input position
    bool isTouching;      // Whether screen is being touched
    float particleSpeed;   // Overall movement speed of particles
    float particleSize;    // Size of each particle dot
    float sphereSize;      // Base radius of the sphere
    float bounceStartTime; // Time when bounce animation started
    float pulseTime;       // Time control for pulsing effect
    bool isPulsing;        // Whether pulse effect is active
    float audioReactivity; // Audio input level (0.0-1.0)
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

[[kernel]]
void particleCompute(device Particle *particles [[buffer(0)]],
                    constant ParticleUniforms &uniforms [[buffer(1)]],
                    constant uint &particleCount [[buffer(2)]],
                    uint id [[thread_position_in_grid]]) {
    if (id >= particleCount) { return; }
    
    Particle particle = particles[id];
    float time = uniforms.time * uniforms.particleSpeed;
    float2 center = uniforms.resolution * 0.5;
    
    float n = float(id);
    float N = float(particleCount);
    
    // Initial clustered animation
    float startupDuration = 2.0;
    float blendFactor = min(time / startupDuration, 1.0);
    
    // Initial state - particles start from center
    float initialRadius = uniforms.sphereSize * 0.1;
    
    // Single consistent rotation calculation for both states
    float rotationSpeed = 0.3;
    float constantRotation = -time * rotationSpeed; // Negative to match initialization direction
    float distributionAngle = 2.0 * M_PI_F * fmod(n * 0.618034, 1.0);
    float phi = distributionAngle + constantRotation;
    
    // Initial clustered state (tighter clustering at center)
    float clusteredTheta = (1.0 - (2.0 * n + 1.0) / N) * 0.2;
    
    // Continuous motion with better distribution
    float wobble = sin(time * 0.5 + n * 0.1) * 0.1;
    float continuousTheta = 1.0 - (2.0 * n + 1.0) / N + wobble;
    
    // More dramatic blend between states
    float easeOutFactor = 1.0 - pow(1.0 - blendFactor, 3.0); // Cubic ease out
    float cosTheta = mix(clusteredTheta, continuousTheta, easeOutFactor);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
    
    float baseRadius = uniforms.sphereSize;
    
    // Blend radius from initial to final size with audio reactivity
    float audioScale = 1.0 + uniforms.audioReactivity * 0.3; // 30% expansion at max audio
    float targetRadius = baseRadius * audioScale;
    float radius = mix(initialRadius, targetRadius, blendFactor);
    
    // Calculate sphere position
    float2 spherePos;
    spherePos.x = cos(phi) * sinTheta * radius;
    spherePos.y = sin(phi) * sinTheta * radius;
    float z = cosTheta * radius;
    
    // Optimize perspective calculation
    float scale = (z + baseRadius * 2) / (baseRadius * 3);
    float2 targetPos = center + spherePos * scale;
    
    // Optimize movement calculation
    float2 toTarget = targetPos - particle.position;
    float dist = fast::length(toTarget); // Use fast:: for better performance
    
    // Increase minimum distance threshold and add minimum velocity
    float minDist = 0.1; // Increased from 0.01
    float minVelocity = 0.01;
    
    if (dist > minDist) {
        float attraction = uniforms.particleSpeed * min(dist * 0.1, 0.8); // Increased attraction and max speed
        particle.velocity = particle.velocity * 0.95 + fast::normalize(toTarget) * attraction; // Less dampening
    } else {
        // Reset position if particle gets stuck
        particle.position = targetPos;
        particle.velocity = float2(0.0);
    }
    
    // Ensure minimum movement
    if (fast::length(particle.velocity) < minVelocity) {
        particle.velocity = fast::normalize(toTarget) * minVelocity;
    }
    
    particle.position += particle.velocity;
    
    // Base life calculation from z-position with more contrast
    float zNormalized = (z / baseRadius) * 0.5 + 0.5;
    float baseLife = 0.2 + 0.8 * pow(zNormalized, 2.0); // More contrast in base brightness
    
    // Add enhanced audio reactivity to brightness
    float audioBoost = uniforms.audioReactivity * 0.9; // Increased audio effect
    float audioModulation = sin(phi * 2.0 + time) * 0.3; // Add variation based on position
    float brightnessMod = audioBoost * (1.0 + audioModulation); // Modulate audio effect
    
    // Combine base brightness with audio reactivity
    float finalBrightness = baseLife + brightnessMod;
    particle.life = clamp(finalBrightness, 0.1, 1.0); // Ensure minimum brightness
    
    particles[id] = particle;
}

[[vertex]]
VertexOut particleVertex(uint vertexID [[vertex_id]]) {
    const float2 vertices[] = {
        float2(-1, -1),
        float2( 3, -1),
        float2(-1,  3)
    };
    
    VertexOut out;
    out.position = float4(vertices[vertexID], 0, 1);
    out.uv = vertices[vertexID] * 0.5 + 0.5;
    return out;
}

[[fragment]]
float4 particleFragment(VertexOut in [[stage_in]],
                       constant ParticleUniforms &uniforms [[buffer(0)]],
                       device Particle *particles [[buffer(1)]],
                       constant uint &particleCount [[buffer(2)]]) {
    float2 uv = in.uv;
    float4 color = float4(0.0);
    
    for (uint i = 0; i < particleCount; i++) {
        Particle particle = particles[i];
        float2 particleUV = particle.position / uniforms.resolution;
        float dist = length(uv - particleUV);
        
        if (dist < uniforms.particleSize) {
            // Sharp, bright particles with soft edges
            float alpha = pow(1.0 - dist / uniforms.particleSize, 3.0) * particle.life;
            color += float4(1.0, 1.0, 1.0, alpha);
        }
    }
    
    return color;
} 