uniform sampler2D u_Tex0;
uniform vec4 u_Color;
uniform float u_Opacity;
varying vec2 v_TexCoord;
void main()
{
    vec4 color = texture2D(u_Tex0, v_TexCoord);
    // Preserve 8-bit premultiplied texture rounding with the straight-alpha blend pipeline.
    if (color.a > 0.0)
        color.rgb = floor(color.rgb * color.a * 255.0 + 0.5) / (255.0 * color.a);
    gl_FragColor = color * u_Color;
    gl_FragColor.a *= u_Opacity;
}
