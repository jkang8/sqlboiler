{{- define "relationship_to_one_eager_helper" -}}
{{- end -}}
{{- if .Table.IsJoinTable -}}
{{- else}}
{{- $dot := . -}}
{{- range .Table.ToManyRelationships -}}
{{- if .ForeignColumnUnique -}}
  {{- template "relationship_to_one_eager_helper" (textsFromOneToOneRelationship $dot.PkgName $dot.Tables $dot.Table .) -}}
{{- else -}}
  {{- $rel := textsFromRelationship $dot.Tables $dot.Table . -}}
  {{- $arg := printf "maybe%s" $rel.LocalTable.NameGo -}}
  {{- $slice := printf "%sSlice" $rel.LocalTable.NameGo}}
  {{- $pkeySlice := printf "%sPrimaryKeyColumns" ($dot.Table.Name | singular | camelCase)}}
// Load{{$rel.Function.Name}} allows an eager lookup of values, cached into the
// relationships structs of the objects.
func (r *{{$rel.LocalTable.NameGo}}Relationships) Load{{$rel.Function.Name}}(e boil.Executor, singular bool, {{$arg}} interface{}) error {
  var slice []*{{$rel.LocalTable.NameGo}}
  var object *{{$rel.LocalTable.NameGo}}

  count := 1
  if singular {
    object = {{$arg}}.(*{{$rel.LocalTable.NameGo}})
  } else {
    slice = {{$arg}}.({{$slice}})
    count = len(slice)
  }

  var args []interface{}
  if singular {
    args = boil.GetStructValues(object, "{{.Column}}")
  } else {
    args = boil.GetSliceValues(slice, "{{.Column}}")
  }

  query := fmt.Sprintf(
    `select * from "{{.ForeignTable}}" where "{{.ForeignColumn}}" in (%s)`,
    strmangle.Placeholders(count, 1, 1),
  )

  results, err := e.Query(query, args...)
  if err != nil {
    return errors.Wrap(err, "failed to eager load {{.ForeignTable}}")
  }
  defer results.Close()

  var resultSlice []*{{$rel.ForeignTable.NameGo}}
  if err = boil.Bind(results, &resultSlice); err != nil {
    return errors.Wrap(err, "failed to bind eager loaded slice {{.ForeignTable}}")
  }

  if singular {
    object.Relationships = &{{$rel.LocalTable.NameGo}}Relationships{
      {{$rel.Function.Name}}: resultSlice,
    }
    return nil
  }

  for _, foreign := range resultSlice {
    for _, local := range slice {
      if local.{{$rel.Function.LocalAssignment}} == foreign.{{$rel.Function.ForeignAssignment}} {
        if local.Relationships == nil {
          local.Relationships = &{{$rel.LocalTable.NameGo}}Relationships{}
        }
        local.Relationships.{{$rel.Function.Name}} = append(local.Relationships.{{$rel.Function.Name}}, foreign)
        break
      }
    }
  }

  return nil
}

{{end -}}{{/* if ForeignColumnUnique */}}
{{- end -}}{{/* range tomany */}}
{{- end -}}{{/* if isjointable */}}
