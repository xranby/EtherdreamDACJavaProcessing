// Fragment shader for bloom effect
#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

#define PROCESSING_TEXTURE_SHADER

uniform sampler2D texture;
uniform float bloomStrength;
uniform float bloomSize;

varying vec4 vertTexCoord;

void main() {
  vec4 color = texture2D(texture, vertTexCoord.st);
  
  // Sample nearby pixels for bloom
  float blurSize = bloomSize * 0.01;
  vec4 bloomColor = vec4(0.0);
  
  // Simple 9-tap blur for bloom
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(-blurSize, -blurSize)) * 0.075;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(0.0, -blurSize)) * 0.125;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(blurSize, -blurSize)) * 0.075;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(-blurSize, 0.0)) * 0.125;
  bloomColor += texture2D(texture, vertTexCoord.st) * 0.2;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(blurSize, 0.0)) * 0.125;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(-blurSize, blurSize)) * 0.075;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(0.0, blurSize)) * 0.125;
  bloomColor += texture2D(texture, vertTexCoord.st + vec2(blurSize, blurSize)) * 0.075;
  
  // Only bloom bright areas
  float brightness = dot(bloomColor.rgb, vec3(0.2126, 0.7152, 0.0722));
  bloomColor *= step(0.4, brightness);
  
  // Add bloom to original color
  vec4 finalColor = color + bloomColor * bloomStrength;
  
  gl_FragColor = finalColor;
}