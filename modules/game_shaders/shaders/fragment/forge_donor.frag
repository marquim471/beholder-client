varying vec2 v_TexCoord;
uniform vec4 u_Color;
uniform sampler2D u_Tex0;

void main()
{
    vec4 texColor = texture2D(u_Tex0, v_TexCoord);
    gl_FragColor = vec4(1.0, 1.0, 1.0, texColor.a) * u_Color;
    if(gl_FragColor.a < 0.01)
        discard;
}
