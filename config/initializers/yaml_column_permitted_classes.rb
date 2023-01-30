Rails.application.config.active_record.yaml_column_permitted_classes =
  [
    ActiveSupport::HashWithIndifferentAccess,
    ActiveSupport::TimeWithZone,
    ActiveSupport::TimeZone,
    ActiveSupport::TimeZone,
    BigDecimal,
    Charta::MultiPolygon,
    Charta::Point,
    Measure,
    Rational,
    RGeo::Geos::CAPIFactory,
    RGeo::Geos::CAPIMultiPolygonImpl,
    RGeo::Geos::CAPIPointImpl,
    RGeo::Geographic::ProjectedMultiPolygonImpl,
    RGeo::Geographic::ProjectedPointImpl,
    RGeo::Geographic::Factory,
    Time,
    Date,
    Nori::StringWithAttributes
  ]
