/// Benim Lezzet Dünyam — API istemcisi.
///
/// `docs/openapi.yaml` sözleşmesinin Dart karşılığı. `musteriapp` ve
/// `mutfakapp` doğrudan `dio`/`http` çağırmaz; hepsi buradan geçer
/// (`AGENTS.md` §2.4).
library;

export 'src/api_exception.dart';
export 'src/bld_api.dart';
export 'src/models/auth.dart';
export 'src/models/catalog.dart';
export 'src/models/converters.dart'
    show
        EtaSource,
        PaymentMethod,
        PaymentStatus,
        ReceiptType,
        UnknownEnumValueException,
        paymentMethodLabelsTr,
        paymentStatusLabelsTr;
export 'src/models/kitchen.dart';
export 'src/models/order.dart';
export 'src/order_source.dart';
export 'src/services.dart';
