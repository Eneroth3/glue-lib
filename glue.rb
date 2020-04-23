# Glue instance to other instance.
#
# Workaround for the SketchUp API CompoenntInstance#glued_to= not supporting
# other instances. Due to technical limitations, the persistent ID is lost for
# the target.
#
# @param instance [Sketchup::ComponentInstance]
# @param target [Sketchup::ComponentInstance]
def glue(instance, target)
  instance.definition.behavior.is2d = true # "is2d" = "gluable"

  corners = [
    Geom::Point3d.new(-1, -1, 0),
    Geom::Point3d.new(1, -1, 0),
    Geom::Point3d.new(1, 1, 0),
    Geom::Point3d.new(-1, 1, 0)
  ].map { |pt| pt.transform(instance.transformation) }

  # If this face merges with other geometry, everything breaks :( .
  # It has to lie loosely in this drawing context though to be able to glue to.
  face = instance.parent.entities.add_face(corners)

  # TODO: Carry over any instances already glued to target.
  instance.glued_to = face

  group = face.parent.entities.add_group([face])
  component = group.to_component

  component.definition = target.definition
  component.layer = target.layer
  component.material = target.material
  component.transformation = target.transformation
  target.erase!
  # TODO: Copy attributes.
  # TODO: Purge temp definition.
end
