"""Original Afterlight GT, authored in Blender. No external geometry or licensed marques."""
import bpy, math, bmesh, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
VARIANT=int(args[0]) if args else 0
MODEL=['AfterlightGT','KometSport','VantaCoupe','AuroraTarga','SpectreSport','AfterlightTrack'][VARIANT]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.4):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
    return m
paint=mat('BodyPaint',(.65,.53,.35),.85,.2); glass=mat('SmokedGlass',(.035,.07,.09),.65,.09)
rubber=mat('TireRubber',(.018,.019,.02),0,.88); silver=mat('BrushedAlloy',(.58,.62,.65),1,.22)
black=mat('CarbonTrim',(.024,.029,.032),.15,.54); brake=mat('BrakeRotor',(.3,.32,.33),.9,.45)
red=mat('BrakeCaliper',(.4,.055,.025),.6,.3); lamp=mat('Headlamp',(.8,.92,1),.35,.15); tail=mat('TailLight',(.8,.018,.025),.3,.2)
def finish(o,name,m,smooth=True):
    o.name=name; o.data.materials.append(m)
    if o.type=='MESH' and smooth:
        for p in o.data.polygons:p.use_smooth=True
    return o

def mesh(name,verts,faces,m,sub=0):
    data=bpy.data.meshes.new(name); data.from_pydata(verts,[],[tuple(reversed(f)) for f in faces]); data.update()
    if name=="Sculpted body":
        bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    o=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(o); finish(o,name,m)
    if sub:
        mod=o.modifiers.new('Surface refinement','SUBSURF'); mod.levels=sub; mod.render_levels=sub
    return o

def box(name,pos,size,m,bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos); o=bpy.context.object; o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Machined edges','BEVEL'); mod.width=bevel; mod.segments=3
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return finish(o,name,m)
def cylinder(name,pos,radius,depth,m,axis='X',verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=pos)
    o=bpy.context.object
    if axis=='X':o.rotation_euler[1]=math.pi/2
    elif axis=='Y':o.rotation_euler[0]=math.pi/2
    mod=o.modifiers.new('Rounded lip','BEVEL');mod.width=.012;mod.segments=2
    return finish(o,name,m)
def tube(name,points,r,m):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=12;curve.bevel_depth=r;curve.bevel_resolution=3
    s=curve.splines.new('POLY');s.points.add(len(points)-1)
    for p,co in zip(s.points,points):p.co=(*co,1)
    o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);o.data.materials.append(m);return o
# A closed loft with broad curved shoulders and a slim nose; y is height, +z is front.
sections=[(-2.40,.75,.69),(-2.36,.90,.76),(-2.13,1.03,.88),(-1.5,1.16,1.01),(-.85,1.04,.96),(-.2,1.02,.95),(.65,1.03,.94),(1.35,1.16,.98),(1.95,1.02,.72),(2.32,.87,.60),(2.38,.72,.57)]
verts=[]
for z,w,top in sections:
    arch=max(0,1-abs(abs(z)-1.45)/.7)
    # The exterior side sweeps upward around the wheel centers.
    bottom=.29
    profile=[(-.82,.30),(-1,bottom),(-1.015,top-.09+arch*.16),(-.96,top+arch*.16),(-.79,top+arch*.12),(-.48,top+.025),(0,top+.03),(.48,top+.025),(.79,top+arch*.12),(.96,top+arch*.16),(1.015,top-.09+arch*.16),(1,bottom),(.82,.30),(0,.28)]
    verts.extend((x*w,y,z) for x,y in profile)
N=14; faces=[]
for i in range(len(sections)-1):
    for j in range(N):faces.append((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j))
faces += [tuple(reversed(range(N))),tuple((len(sections)-1)*N+j for j in range(N))]
body=mesh('Sculpted body',verts,faces,paint,2)
# Four true wheel wells, with continuous sculpted shoulders above them.
bpy.context.view_layer.objects.active=body;body.select_set(True)
for modifier in list(body.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
for side in [-1,1]:
    for z in [-1.45,1.45]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.51,depth=.75,location=(side*1.17,.48,z),rotation=(0,math.pi/2,0))
        cutter=bpy.context.object;cutter.name='Wheel well cutter'
        mod=body.modifiers.new('True wheel opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
        bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
edge=body.modifiers.new('Fender edge highlight','BEVEL');edge.width=.012;edge.segments=2

# Low coupe glasshouse, rounded roof and individually framed glazing.
roof=[(-1.46,.79,.91),(-1.0,.67,1.34),(-.6,.64,1.42),(-.15,.64,1.41),(.32,.70,1.30),(.88,.84,.95)]
v=[]
for z,w,h in roof:v += [(-w,.89,z),(-w,h-.045,z),(-w*.9,h,z),(0,h+.025,z),(w*.9,h,z),(w,h-.045,z),(w,.89,z)]
f=[]
for i in range(len(roof)-1):
    for j in range(6):f.append((i*7+j,i*7+j+1,(i+1)*7+j+1,(i+1)*7+j))
if VARIANT==3:
    # Targa opening: retain side glass and front/rear windshields, remove central roof faces.
    f=[face for face in f if not (all(7<=idx<35 for idx in face) and any(idx%7 in [2,3,4] for idx in face))]
mesh('Panoramic glasshouse',v,f,glass,2)
# A metal roof panel above the glazed shell.
if VARIANT not in [1,3,4]:mesh('Floating roof',[(-.56,1.437,-.90),(.56,1.437,-.90),(.55,1.448,-.15),(-.55,1.448,-.15)],[(0,1,2,3)],paint,0)
if VARIANT==3:
    box('Targa roll hoop',(0,1.30,-.82),(1.36,.10,.12),silver,.035)
    for x in [-.37,.37]:box('Leather seat',(x,.94,-.2),(.48,.39,.55),black,.08)
if VARIANT in [2,4,5]:
    wingHeight=1.26 if VARIANT==5 else 1.05
    box('Rear aerofoil',(0,wingHeight,-1.98),(2.20,.07,.32),black,.025)
    for x in [-.72,.72]:box('Wing upright',(x,wingHeight-.14,-1.98),(.065,.28,.09),silver,.01)
for side in [-1,1]:
    tube('Window chrome',[(side*.83,.94,-1.45),(side*.68,1.30,-1.0),(side*.65,1.39,-.6),(side*.65,1.38,-.15),(side*.7,1.27,.32),(side*.83,.96,.86)],.014,silver)
    tube('Door glass sill',[(side*.82,.94,-1.4),(side*.9,.94,-.1),(side*.83,.94,.85)],.02,paint)
    tube('B pillar',[(side*.67,1.35,-.6),(side*.9,.95,-.65)],.035,black)
    tube('Door seam',[(side*1.012,.88,.45),(side*1.012,.48,.3),(side*.995,.39,-.82),(side*1.02,.86,-.98)],.006,black)
    box('Flush handle',(side*1.018,.82,-.65),(.018,.028,.16),silver,.006)
    box('Mirror',(side*1.09,1.01,.55),(.22,.115,.27),paint,.045)
    box('Mirror glass',(side*1.09,1.01,.407),(.17,.075,.015),glass,.02)
    box('Side skirt',(side*.98,.31,-.05),(.11,.10,1.75),black,.025)
    # Smooth ring around actual open arch: upper half and lips.
    for z in [-1.45,1.45]:
        points=[(side*1.16,.48+.513*math.sin(t),z+.513*math.cos(t)) for t in [i*math.pi/24 for i in range(25)]]
        tube('Wheel arch lip',points,.024,paint)
        x=side*1.055
        cylinder('Tire',(x,.48,z),.465,.27,rubber)
        cylinder('Rotor',(side*1.19,.48,z),.28,.025,brake)
        # Genuine open spoke geometry; rotor visible behind it.
        cylinder('Wheel hub',(side*1.216,.48,z),.077,.035,silver)
        bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,location=(side*1.22,.48,z),major_radius=.318,minor_radius=.023,rotation=(0,math.pi/2,0));finish(bpy.context.object,'Rim lip',silver)
        for k in range(10):
            a=k*2*math.pi/10; center=(side*1.215,.48+math.cos(a)*.19,z+math.sin(a)*.19)
            o=box('Alloy spoke',center,(.036,.27,.034),silver,.009);o.rotation_euler[0]=a
        box('Caliper',(side*1.175,.48,z+.22),(.06,.24,.1),red,.015)
        for k in range(48):
            a=k*2*math.pi/48
            box('Tread',(x,.48+math.cos(a)*.463,z+math.sin(a)*.463),(.235,.004,.013),black,.003).rotation_euler[0]=a
        cylinder('Center crest',(side*1.24,.48,z),.032,.009,paint)
# Clean front fascia with mesh grille and slim LEDs.
for side in [-1,1]:
    tube('Bonnet seam',[(side*.72,.968,.78),(side*.73,1.03,1.23),(side*.7,.80,1.90),(side*.61,.66,2.20)],.005,black)
box('Front splitter',(0,.30,2.19),(1.78,.075,.25),black,.02)
box('Grille surround',(0,.48,2.34),(1.05,.18,.04),silver,.035)
box('Grille insert',(0,.48,2.366),(.98,.145,.022),black,.028)
for x in [-.4,-.3,-.2,-.1,0,.1,.2,.3,.4]:box('Grille vane',(x,.48,2.382),(.013,.13,.016),silver,.003)
for side in [-1,1]:
    box('Headlight housing',(side*.69,.64,2.245),(.40,.10,.12),black,.035)
    box('LED blade',(side*.69,.66,2.31),(.35,.024,.017),lamp,.009)
    box('Lower intake',(side*.72,.43,2.28),(.28,.12,.04),black,.025)
    box('Rear lamp',(side*.61,.78,-2.32),(.63,.033,.032),tail,.012)
    cylinder('Exhaust',(side*.7,.36,-2.36),.068,.18,silver,axis='Z')
box('Rear diffuser',(0,.30,-2.20),(1.79,.11,.27),black,.03)
for x in [-.65,-.32,0,.32,.65]:box('Diffuser fin',(x,.28,-2.2),(.022,.12,.25),black,.004)
# Remove the GT-specific bright window frames from the wedge and hatch variants.
if VARIANT in [1,4]:
    for o in list(bpy.data.objects):
        if o.name.startswith(('Window chrome','B pillar')):bpy.data.objects.remove(o,do_unlink=True)
# Export evaluated geometry, no external dependencies; keep source .blend for editing.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/('Resources/Models/'+MODEL+'.blend')))
# Convert curves to meshes and apply all modifiers for portable runtime OBJ.
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
scale=[(1,1,1),(.95,1.06,.87),(1,1,1.04),(1.02,1,1),(1.08,.84,1.03),(1.05,1,1.06)][VARIANT]
from mathutils import Matrix
transform=Matrix.Diagonal((*scale,1))
for o in bpy.data.objects:
    if o.type=='MESH':o.matrix_world=transform @ o.matrix_world
bpy.ops.wm.obj_export(filepath=str(ROOT/('Resources/Models/'+MODEL+'.obj')),export_selected_objects=False,forward_axis='Y',up_axis='Z',export_materials=True,apply_modifiers=True,export_triangulated_mesh=True)
print('AFTERLIGHT_GT_EXPORTED')
