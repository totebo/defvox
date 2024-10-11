varying mediump vec2 var_texcoord0;  // Texture coordinates from vertex shader
uniform mediump sampler2D tex0;      // The texture sampler
uniform lowp vec4 tint;

void main() {
    // Sample the texture using the texture coordinates
    vec4 tint_pm = vec4(tint.xyz * tint.w, tint.w);
    vec4 color = texture2D(tex0, var_texcoord0) * tint_pm;

    // Output the color without modifying transparency
    gl_FragColor = color;
}
