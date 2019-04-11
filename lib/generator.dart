import 'dart:async';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
// ignore: implementation_imports

class ModuxGenerator extends Generator {
  @override
  Future<String> generate(LibraryReader library, BuildStep buildStep) async {
    final result = new StringBuffer();

    try {
      var hasWrittenHeaders = false;
      for (final element in library.allElements) {
        if (_needsModuxActions(element) && element is ClassElement) {
          if (!hasWrittenHeaders) {
            hasWrittenHeaders = true;
            result.writeln(_lintIgnores);
          }
          log.info('Generating action classes for ${element.name}');
          result.writeln(_generateActions(element));
        }
      }
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      return '/*\n'
          '${e?.toString()}\n'
          '$stackTrace'
          '*/';
    }

    return result.toString();
  }
}

String _cleanFullName(String fullName) {
  if (fullName == null) return '';
  if (fullName.startsWith('/')) fullName = fullName.substring(1);
  return fullName.replaceFirst('/lib/', '/').replaceFirst('|lib/', '/');
}

const _statefulModuxActionsName = 'StatefulActionsOptions';
const _statelessModuxActionsName = 'StatelessActionsOptions';

bool _needsModuxActions(Element element) =>
    element is ClassElement && _hasSuperType(element, 'ModuxActions');

bool _hasSuperType(ClassElement classElement, String type) =>
    classElement.allSupertypes
        .any((interfaceType) => interfaceType.name == type) &&
    !classElement.displayName.startsWith('_\$');

const _lintIgnores = """
// ignore_for_file: avoid_classes_with_only_static_members
// ignore_for_file: annotate_overrides
""";

String _generateActions(ClassElement element) => _generateDispatchersIfNeeded(
    element); // + _actionNamesClassTemplate(element);
//    _generateDispatchersIfNeeded(element) + _actionNamesClassTemplate(element);

String _generateDispatchersIfNeeded(ClassElement element) =>
    element.constructors.length > 1
        ? _stateActionsDispatcherTemplate(element)
        : '';

class ClassType {
  final DartType type;
  final ClassElement element;
  final ClassType supertype;
  final List<ClassProperty> props = [];
  List<TypeParameterElement> _params;
  String _parameterizedName;

  bool _moduxActions = false;
  bool __isModuxActions = false;
  bool _isStateless = false;
  bool _isStateful = false;
  bool _isCommandDispatcher = false;
  bool _commandDispatcher = false;
  bool _isBuiltCommandDispatcher = false;
  bool _builtCommandDispatcher = false;
  bool _isNestedBuiltCommandDispatcher = false;
  bool _nestedBuiltCommandDispatcher = false;
  ClassType _reduxActionsType;
  bool _isActionDispatcher = false;
  bool _isFieldActionDispatcher = false;
  bool _isBuilt = false;

  bool _isRouteActions = false;
  bool _routeActions = false;
  bool _isModelActions = false;
  bool _modelActions = false;

  DartType _stateType;
  DartType _actionsType;

  String _stateName;
  String _builderName;
  String _actionsName;
  String _fullName;

  DartType _commandType;
  DartType _commandPayloadType;
  String _commandName;
  String _commandBuilderName;
  String _commandPayloadName;
  String _commandPayloadBuilderName;
  DartType _resultType;
  DartType _resultPayloadType;
  String _resultName;
  String _resultBuilderName;
  String _resultPayloadName;
  String _resultPayloadBuilderName;

  String get displayName =>
      type?.displayName ?? element?.displayName ?? type?.name ?? '';

  DartType _typeArgAt(int index) {
    if (type is! InterfaceType) return null;
    final InterfaceType t = type as InterfaceType;
    final args = t.typeArguments;
    if (args == null || args.isEmpty) return null;
    if (args.length <= index) return null;
    return args[index];
  }

  List<TypeParameterElement> get params {
    if (_params != null) return _params;
    if (type is! InterfaceType) {
      _params = [];
      return _params;
    }
    _params = (type as InterfaceType).typeParameters;
    return _params;
  }

  String get parameterizedName {
    if (_parameterizedName != null) return _parameterizedName;
    final params = this.params;
    if (params.isEmpty) {
      _parameterizedName = type?.displayName ?? type?.name;
      return _parameterizedName;
    }

    final buffer = StringBuffer('${type.name}<');
    bool first = true;
    for (final param in params) {
      if (first) {
        first = false;
      } else {
        buffer.write(', ');
      }
      buffer.write(param.displayName);
    }
    buffer.write('>');
    _parameterizedName = buffer.toString();
    return _parameterizedName;
  }

  ClassType(this.type, this.element, this.supertype) {
    if (element == null) {
      __isModuxActions = false;
    } else {
      _fullName = _cleanFullName(element?.source?.fullName);
      _isActionDispatcher = isPackageClass('modux', 'ActionDispatcher');
      _isFieldActionDispatcher = isPackageClass('modux', 'FieldDispatcher');
      __isModuxActions = isPackageClass('modux', 'ModuxActions');
      _isStateless = isPackageClass('modux', 'StatelessActions');
      _isStateful = isPackageClass('modux', 'StatefulActions');
      _isCommandDispatcher = isPackageClass('modux', 'CommandDispatcher');
      _isBuiltCommandDispatcher =
          isPackageClass('modux', 'BuiltCommandDispatcher');
      _isNestedBuiltCommandDispatcher =
          isPackageClass('modux', 'NestedBuiltCommandDispatcher');
      _isRouteActions = isPackageClass('modux', 'RouteActions');
      _isModelActions = isPackageClass('modux', 'ModelActions');
      _isBuilt = doesImplement('built_value', 'Built');

      if (_isRouteActions) {
        if (type is InterfaceType) {
          final args = (type as InterfaceType).typeArguments;
          _resultType = args[2];
          _resultName = _resultType.displayName ?? _resultType.name;
          final index = _resultName.indexOf('<');
          if (index > -1) {
            _resultBuilderName = _resultName.substring(0, index) +
                'Builder' +
                _resultName.substring(index);
          } else {
            _resultBuilderName = '${_resultName}Builder';
          }
        }
      }

      if (_isCommandDispatcher) {
        if (type is InterfaceType) {
          final args = (type as InterfaceType).typeArguments;
          _commandType = args[0];
//          _resultType = args[1];
        }
      }

      if (_isBuiltCommandDispatcher) {
        if (type is InterfaceType) {
          final args = (type as InterfaceType).typeArguments;
          _commandType = args[0];
          _resultType = args[2];

          {
            _commandName = _commandType.displayName ?? _commandType.name;
            final index = _commandName.indexOf('<');
            if (index > -1) {
              _commandBuilderName = _commandName.substring(0, index) +
                  'Builder' +
                  _commandName.substring(index);
            } else {
              _commandBuilderName = '${_commandName}Builder';
            }
          }

          {
            _resultName = _resultType.displayName ?? _resultType.name;
            final index = _resultName.indexOf('<');
            if (index > -1) {
              _resultBuilderName = _resultName.substring(0, index) +
                  'Builder' +
                  _resultName.substring(index);
            } else {
              _resultBuilderName = '${_resultName}Builder';
            }
          }
        }
      }

      if (_isNestedBuiltCommandDispatcher) {
        if (type is InterfaceType) {
          final args = (type as InterfaceType).typeArguments;
          _commandPayloadType = args[2];
          _resultPayloadType = args[6];

          {
            _commandPayloadName =
                _commandPayloadType.displayName ?? _commandPayloadType.name;
            final index = _commandPayloadName.indexOf('<');
            if (index > -1) {
              _commandPayloadBuilderName =
                  _commandPayloadName.substring(0, index) +
                      'Builder' +
                      _commandPayloadName.substring(index);
            } else {
              _commandPayloadBuilderName = '${_commandPayloadName}Builder';
            }
          }

          {
            _resultPayloadName =
                _resultPayloadType.displayName ?? _resultPayloadType.name;
            final index = _resultPayloadName.indexOf('<');
            if (index > -1) {
              _resultPayloadBuilderName =
                  _resultPayloadName.substring(0, index) +
                      'Builder' +
                      _resultPayloadName.substring(index);
            } else {
              _resultPayloadBuilderName = '${_resultPayloadName}Builder';
            }
          }
        }
      }

      ClassType s = supertype;
      while (s != null) {
        if (s._isBuilt) _isBuilt = true;
        if (s._isActionDispatcher) _isActionDispatcher = true;
        if (s._isFieldActionDispatcher) _isFieldActionDispatcher = true;

        if (s._isModelActions) _modelActions = true;

        if (s._isCommandDispatcher) {
          _commandDispatcher = true;
        }

        if (s._isBuiltCommandDispatcher) {
          _builtCommandDispatcher = true;
          _commandName = s._commandName;
          _commandBuilderName = s._commandBuilderName;
          _resultType = s._resultType;
          _resultName = s._resultName;
          _resultBuilderName = s._resultBuilderName;
        }

        if (s._isNestedBuiltCommandDispatcher) {
          _nestedBuiltCommandDispatcher = true;
          _commandPayloadType = s._commandPayloadType;
          _commandPayloadName = s._commandPayloadName;
          _commandPayloadBuilderName = s._commandPayloadBuilderName;
          _resultPayloadType = s._resultPayloadType;
          _resultName = s._resultName;
          _resultBuilderName = s._resultBuilderName;
          _resultPayloadName = s._resultPayloadName;
          _resultPayloadBuilderName = s._resultPayloadBuilderName;
        }

        if (s._isRouteActions) {
          _routeActions = true;

          _resultName = s._resultName;
          _resultBuilderName = s._resultBuilderName;

          _moduxActions = true;
          _reduxActionsType = s;
          _stateType = s._typeArgAt(0);
          _stateName = _stateType.displayName ?? _stateType.name;
          final index = _stateName.indexOf('<');
          if (index > -1) {
            _builderName = _stateName.substring(0, index) +
                'Builder' +
                _stateName.substring(index);
          } else {
            _builderName = '${_stateName}Builder';
          }

          _actionsType = s._typeArgAt(3);
          _actionsName = _actionsType.displayName;
        }

        if (s._isStateful) {
          _isStateful = true;
        }

        if (s._isStateless) {
          _isStateless = true;
          _actionsType = s._typeArgAt(0);
          _actionsName = _actionsType.displayName;
        }

        if (s.__isModuxActions) {
          _moduxActions = true;
          _reduxActionsType = s;
          _stateType = s._typeArgAt(0);
          _stateName = _stateType.displayName ?? _stateType.name;
          final index = _stateName.indexOf('<');
          if (index > -1) {
            _builderName = _stateName.substring(0, index) +
                'Builder' +
                _stateName.substring(index);
          } else {
            _builderName = '${_stateName}Builder';
          }

          _actionsType = s._typeArgAt(2);
          _actionsName = _actionsType.displayName;
        }
//        if (s._isRouteActions) {
//          _routeActions = true;
//          _stateType = s._typeArgAt(0);
//          _stateName = _stateType.displayName ?? _stateType.name;
//          final index = _stateName.indexOf('<');
//          if (index > -1) {
//            _builderName = _stateName.substring(0, index) +
//                'Builder' +
//                _stateName.substring(index);
//          } else {
//            _builderName = '${_stateName}Builder';
//          }
//
//          _outType = s._typeArgAt(2);
//          _actionsType = s._typeArgAt(3);
//          _actionsName = _actionsType.displayName;
//        } else if (s._isModelActions || s._isStateful) {
//          if (s._isModelActions) _modelActions = true;
//          _stateType = s._typeArgAt(0);
//          _stateName = _stateType.displayName ?? _stateType.name;
//          final index = _stateName.indexOf('<');
//          if (index > -1) {
//            _builderName = _stateName.substring(0, index) +
//                'Builder' +
//                _stateName.substring(index);
//          } else {
//            _builderName = '${_stateName}Builder';
//          }
//
//          _actionsType = s._typeArgAt(2);
//          _actionsName = _actionsType.displayName;
//        }
        s = s.supertype;
      }
    }
  }

  String get reducerTypeName =>
      _superMethod(type, '\$reducer')?.parameters?.first?.type?.name ??
      'ReducerBuilder';

  String get middlewareTypeName =>
      _superMethod(type, '\$middleware')?.parameters?.first?.type?.name ??
      'MiddlwareBuilder';

  bool get isModuxActions => _moduxActions;

  ClassType get reduxActionsType => _reduxActionsType;

  String get stateName => _stateName;

  String get builderName => _builderName;

  String get actionsName => _actionsName;

  bool get isStateless => _isStateless;

  bool get isStateful => !_isStateless && _moduxActions;

  bool get isModuxActionsCovariant => false;

  bool get isActionDispatcher => _isActionDispatcher;

  bool get isFieldActionDispatcher => _isFieldActionDispatcher;

  bool get isBuilt => _isBuilt;

  bool doesImplement(String packageName, String className) {
    if (element == null) return false;
    try {
      return element.allSupertypes.firstWhere((t) {
            if (t.name != className) return false;
            try {
              final el = t.element;
              if (el == null) return false;
              final src = el.source;
              if (src == null) return false;
              final fullName = src.fullName;
              if (fullName == null) return false;

              return (fullName.startsWith(packageName));
            } catch (e) {
              return false;
            }
          }) !=
          null;
    } catch (e) {
      return false;
    }
  }

  bool isPackageClass(String packageName, String className) {
    if (element == null) return false;
    final s = element.source;
    if (s == null) return false;
    return _fullName.startsWith('$packageName/') &&
        _removeGenerics(element.name) == className;
  }

  bool isPackage(String packageName, InterfaceType t) {
    if (t == null || packageName == null || packageName.isEmpty) return false;

//    final element = t.element;
//    if (element == null) return false;
//    final s = element.source;
//    if (s == null) return false;
//
//    var fullName = _cleanFullName(s.fullName);
//    if (fullName.startsWith('asset:')) {
//      fullName = fullName.substring('asset:'.length);
//    } else if (fullName.startsWith('package:')) {
//      fullName = fullName.substring('package:'.length);
//    }

    return _fullName.startsWith('$packageName/');
  }

  void forEachProperty(void fn(ClassType enclosing, ClassProperty prop),
      {bool inherited = true}) {
    if (inherited) supertype?.forEachProperty(fn);
    props.forEach((prop) => fn?.call(this, prop));
  }

  String resolveFullType(InterfaceType t, {String append = ''}) {
    if (t.typeArguments.isNotEmpty) {
      final buffer = StringBuffer('FullType(${t.name}$append');
      bool first = true;
      for (final arg in t.typeArguments) {
        if (first) {
          first = false;
          buffer.write(', [');
        } else {
          buffer.write(', ');
        }

        buffer.write(resolveFullType(arg));
      }
      if (!first) buffer.write(']');
      buffer.write(')');
      return buffer.toString();
    } else {
      return 'FullType(${t.name})';
    }
  }

  static ClassType of(
    DartType type, {
    ParsedLibraryResult library,
  }) {
    if (type == null) return null;
    if (type is! InterfaceType) return null;
    if (type.name == 'Object') return null;

    final t = type as InterfaceType;
    ClassElement element = null;
    ClassType supertype = null;

    try {
      element = t.element;
    } catch (e) {}

    final superclass = t.superclass;
    if (superclass != null) {
      supertype = of(superclass);
    }

    final classType = ClassType(t, element, supertype);
    if (!classType.isModuxActions &&
        !classType.isActionDispatcher &&
        !classType.isFieldActionDispatcher) return classType;

    if (element != null) {
      t.accessors
          .where((f) =>
              !f.isStatic &&
              f.returnType != null &&
              f.returnType.element != null)
          .map((el) {
            String displayName;

            if (library != null) {
              try {
                final typeFromAst = (library.getElementDeclaration(el).node
                            as MethodDeclaration)
                        ?.returnType
                        ?.toSource() ??
                    'dynamic';

                final typeFromElement = el.returnType.displayName;

                // If the type does not have an import prefix, prefer the element result.
                // It handles inherited generics correctly.
                if (!typeFromAst.contains('.')) {
                  displayName = typeFromElement;
                } else {
                  displayName = typeFromAst;
                }
              } catch (e) {
                try {
                  displayName = el.returnType.displayName;
                } catch (e) {
                  displayName = el.returnType.name;
                }
              }
            }

            if (displayName == null) {
              try {
                displayName = el.returnType.displayName;
              } catch (e) {
                displayName = el.returnType.name;
              }
            }

            var propType =
                // Self Referencing?
                (el.returnType.displayName == classType.type.displayName)
                    ? classType
                    : ClassType.of(el.returnType, library: library);

            ClassType actionType = null;
            String paramName = '';

            if (propType?.isFieldActionDispatcher ?? false) {
              final firstArg = propType._typeArgAt(0);

              if (firstArg != null) {
                if (firstArg.isDynamic) {
//                  try {
//                    paramName = firstArg.element.name;
//                  } catch (e) {}
                } else if (firstArg is InterfaceType) {
                  actionType = ClassType.of(firstArg, library: library);
                }
              }
            }

            return ClassProperty(el, propType, displayName,
                actionType: actionType, paramName: paramName);
          })
          .where((prop) => prop.type != null)
          .where((prop) =>
              prop.type.isModuxActions ||
              prop.type.isActionDispatcher ||
              prop.type.isFieldActionDispatcher)
          .forEach((prop) => classType.props.add(prop));
    }

    return classType;
  }
}

class ClassProperty {
  final PropertyAccessorElement element;
  final ClassType type;
  final String displayName;
  final String displayPrefix;
  final ClassType actionType;
  final String paramName;

  ClassProperty(this.element, this.type, this.displayName,
      {this.actionType, this.paramName = ''})
      : displayPrefix = prefixOf(displayName);

  bool get isActionDispatcher => type.isActionDispatcher;

  bool get isFieldActionDispatcher => type.isFieldActionDispatcher;

  bool get isModuxActions => type._moduxActions;

  bool get isStateful => type._moduxActions && !type._isStateless;

  bool get isStateless => type.isStateless;

  bool get isBuilt => type.isBuilt;

  String get name => element.name;

  String withPrefix(String name) {
    if (displayPrefix == null || displayPrefix.isEmpty) return name;
    return '$displayPrefix.$name';
  }

  String get stateDisplayName {
    var t = type._stateType;
    if (t == null) return '';
    if (t is! InterfaceType) return t.displayName;
    return resolve(t);
  }

  String get builderDisplayName {
    var t = type._stateType;
    if (t == null) return '';
    if (t is! InterfaceType) return t.displayName;
    return resolve(t, append: 'Builder');
  }

  String resolve(InterfaceType t, {String append = ''}) {
    if (t.typeArguments.isNotEmpty) {
      final buffer = StringBuffer(t.name + append);
      buffer.write('<');
      bool first = true;
      for (final arg in t.typeArguments) {
        if (first) {
          first = false;
        } else {
          buffer.write(', ');
        }

        if (arg is InterfaceType) {
          buffer.write(resolve(arg));
        }
      }
      buffer.write('>');
      return buffer.toString();
    } else {
      return withPrefix(t.displayName + append);
    }
  }

  static String prefixOf(String displayName) {
    if (displayName == null || displayName.isEmpty) return '';
    final index = displayName.indexOf('.');
    if (index < 0) return '';
    return displayName.substring(0, index);
  }
}

String _escape(String s) => s?.replaceAll('\$', '\\\$') ?? '';

ImportElement _moduxImport(ClassElement element) {
  try {
    element.library?.imports?.firstWhere(
        (el) => el?.toString()?.contains('package:modux/modux.dart') ?? false);
  } catch (e) {
    return null;
  }
}

String _moduxImportPrefix(ClassElement element) {
  try {
    final prefix = element.library?.imports
        ?.firstWhere((el) =>
            el?.toString()?.contains('package:modux/modux.dart') ?? false)
        ?.prefix;

    return prefix == null ? '' : '$prefix.';
  } catch (e) {
    return null;
  }
}

String _stateActionsDispatcherTemplate(ClassElement element) {
//  final moduxPrefix = _moduxImportPrefix(element);
//  print('Modux Prefix: $moduxPrefix');

  // ignore: deprecated_member_use
  final parsedLibrary = ParsedLibraryResultImpl.tmp(element.library);
  final ClassType classType =
      ClassType.of(element.type, library: parsedLibrary);
  if (classType == null || !classType.isModuxActions) {
    return '';
  }

//  final generateActions =
//      element.metadata.firstWhere((a) => a.element.name == 'GenerateActions');

  String stateType = '';
  String builderType = '';
  String generics = '';
  String optionsClass = '';

//  final _p = classType?.type?.typeParameters
//          ?.map((el) => el.displayName)
//          ?.reduce((v, e) => v + ', ' + e) ??
//      '';
//  final params = _p.isNotEmpty ? '<$_p>' : '';

  if (classType.isStateful) {
    stateType = classType.stateName;
    builderType = classType.builderName;
    generics = '<$stateType, $builderType, ${classType.displayName}>';
    optionsClass = '$_statefulModuxActionsName$generics';
  } else {
    generics = '<${element.name}>';
    optionsClass = '$_statelessModuxActionsName$generics';
  }

  final writer = StringBuffer();

  final String implOptionsName = _appendName(classType.displayName, 'Options');

  writer.writeln('typedef $optionsClass $implOptionsName();');
  writer.writeln();

  writer.writeln(
      'class _\$${classType.type.displayName} extends ${classType.type.displayName} {');

  writer.writeln('final $optionsClass \$options;');

  writer.writeln();
  classType.forEachProperty((enclosing, prop) {
    writer.writeln('final ${prop.displayName} ${prop.name};');
  });

  int nestedCount = 0;
  int actionCount = 0;
  int fieldActionCount = 0;

  writer.writeln();
  writer.writeln('_\$${element.name}._(this.\$options) : ');
  classType.forEachProperty((enclosing, prop) {
    if (prop.isModuxActions) {
      nestedCount++;
      if (prop.isStateless) {
        final mapper = '(a) => a.${prop.name}';
        writer.writeln(
            '${prop.name} = ${prop.displayName}(() => \$options.stateless<'
            '${prop.type.actionsName}>(\'${_escape(prop.name)}\', $mapper)),');
      } else if (prop.isStateful) {
        final mapper = '(a) => a.${prop.name}';
        final stateMapper = '(s) => s?.${prop.name}';
        final builderMapper = '(b) => b?.${prop.name}';
        final replaceMapper =
            '(parent, builder) => parent?.${prop.name} = builder';

        writer.writeln(
            '${prop.name} = ${prop.displayName}(() => \$options.stateful<'
            '${prop.stateDisplayName}, '
            '${prop.builderDisplayName}, '
            '${prop.displayName}'
            '>(\'${_escape(prop.name)}\', '
            '$mapper, '
            '$stateMapper, '
            '$builderMapper, '
            '$replaceMapper)),');
      }
    } else if (prop.isFieldActionDispatcher) {
      fieldActionCount++;
      final index = prop.displayName.indexOf('<');
      String actionGenerics = '';
      if (index > -1) {
        actionGenerics = prop.displayName.substring(index);
      }

      writer.writeln(
          '${prop.name} = \$options.actionField$actionGenerics(\'${_escape(prop.name)}\', '
          '(a) => a?.${prop.name}, '
          '(s) => s?.${prop.name}, '
          '(p, b) => p?.${prop.name} = '
          'b${(prop?.actionType?.isBuilt ?? false) ? '?.toBuilder()' : ''}),');
    } else if (prop.isActionDispatcher) {
      actionCount++;
      final index = prop.displayName.indexOf('<');
      String actionGenerics = '';
      if (index > -1) {
        actionGenerics = prop.displayName.substring(index);
      }
      writer.writeln('${prop.name} = \$options.action$actionGenerics'
          '(\'${_escape(prop.name)}\', (a) => a?.${prop.name}),');
    }
  });
  writer.writeln('super._();');

  writer.writeln();
  writer.writeln(
      'factory _\$${element.name}($implOptionsName options) => _\$${element.name}._(options());');

  if (classType.isStateful) {
    final getter = element.getGetter('\$initial');
    if (getter == null || getter.isAbstract) {
      writer.writeln();
      writer.writeln('@override');
      writer.writeln('$stateType get \$initial => $stateType();');
    }

    writer.writeln();
    writer.writeln('@override');
    writer.writeln(
        '${classType.builderName} \$newBuilder() => ${classType.builderName}();');
  }

  if (nestedCount > 0) {
    writer.writeln();
    writer.writeln('BuiltList<ModuxActions> _\$nested;');
    writer.writeln('@override');
    writer.writeln(
        'BuiltList<ModuxActions> get \$nested => _\$nested ??= BuiltList<ModuxActions>([');
    classType.forEachProperty((enclosing, prop) {
      if (prop.isModuxActions) {
        writer.writeln('this.${prop.name},');
      }
    });
    writer.writeln(']);');
  }

  if (actionCount > 0 || fieldActionCount > 0) {
    writer.writeln();
    writer.writeln('BuiltList<ActionDispatcher> _\$actions;');
    writer.writeln('@override');
    writer.writeln(
        'BuiltList<ActionDispatcher> get \$actions => _\$actions ??= BuiltList<ActionDispatcher>([');
    classType.forEachProperty((enclosing, prop) {
      if (prop.isActionDispatcher || prop.isFieldActionDispatcher) {
        writer.writeln('this.${prop.name},');
      }
    });
    writer.writeln(']);');
  }

  if (nestedCount > 0 || fieldActionCount > 0) {
    writer.writeln();
    writer.writeln('@override');
    writer.writeln('void \$reducer(${classType.reducerTypeName} reducer) {');
    writer.writeln('super.\$reducer(reducer);');
    classType.forEachProperty((enclosing, prop) {
      if (prop.isModuxActions || prop.isFieldActionDispatcher) {
        writer.writeln('${prop.name}.\$reducer(reducer);');
      }
    });
    writer.writeln('}');

    writer.writeln();
    writer.writeln('@override');
    writer.writeln(
        'void \$middleware(${classType.middlewareTypeName} middleware) {');
    writer.writeln('super.\$middleware(middleware);');
    classType.forEachProperty((enclosing, prop) {
      if (prop.isModuxActions) {
        writer.writeln('${prop.name}.\$middleware(middleware);');
      }
    });
    writer.writeln('}');
  }

  if (classType.isStateful) {
    final fullType = _toFullType(classType.stateName);
    if (fullType != null && fullType.isNotEmpty) {
      writer.writeln();
      writer.writeln('FullType _\$fullType;');
      writer.writeln('@override');
      writer.writeln('FullType get '
          '\$fullType => _\$fullType ??= $fullType;');
    }
  }

  if (classType._routeActions) {
    writer.writeln();
    writer.writeln('@override');
    writer.writeln('${classType._resultBuilderName} \$newResultBuilder() => '
        '${classType._resultName}().toBuilder();');
  }

  if (classType._builtCommandDispatcher) {
    writer.writeln();
    writer.writeln('@override');
    writer.writeln('${classType._commandBuilderName} newCommandBuilder() => '
        '${classType._commandName}().toBuilder();');

    writer.writeln();
    writer.writeln('@override');
    writer.writeln('${classType._resultBuilderName} newResultBuilder() => '
        '${classType._resultName}().toBuilder();');

    final commandType = classType._commandType;
    if (commandType != null &&
        !commandType.isDynamic &&
        commandType is InterfaceType) {
      final serializer = commandType?.element?.getGetter('serializer');
      if (serializer != null) {
        writer.writeln();
        writer.writeln('@override');
        writer.writeln('Serializer<${commandType.name}> get '
            'commandSerializer => ${commandType.name}.serializer;');
      }
    }

    final resultType = classType._resultType;
    if (resultType != null &&
        !resultType.isDynamic &&
        resultType is InterfaceType) {
      final serializer = resultType?.element?.getGetter('serializer');
      if (serializer != null) {
        writer.writeln();
        writer.writeln('@override');
        writer.writeln('Serializer<${resultType.name}> get '
            'resultSerializer => ${resultType.name}.serializer;');
      }
    }
  }

  if (classType._nestedBuiltCommandDispatcher) {
    writer.writeln();
    writer.writeln('@override');
    writer.writeln(
        '${classType._commandPayloadBuilderName} newCommandPayloadBuilder() => '
        '${classType._commandPayloadName}().toBuilder();');

    writer.writeln();
    writer.writeln('@override');
    writer.writeln(
        '${classType._resultPayloadBuilderName} newResultPayloadBuilder() => '
        '${classType._resultPayloadName}().toBuilder();');

    final commandType = classType._commandPayloadType;
    if (commandType != null &&
        !commandType.isDynamic &&
        commandType is InterfaceType) {
      final serializer = commandType?.element?.getGetter('serializer');
      if (serializer != null) {
        writer.writeln();
        writer.writeln('@override');
        writer.writeln('Serializer<${commandType.name}> get '
            'commandPayloadSerializer => ${commandType.name}.serializer;');
      }
    }

    final resultType = classType._resultPayloadType;
    if (resultType != null &&
        !resultType.isDynamic &&
        resultType is InterfaceType) {
      final serializer = resultType?.element?.getGetter('serializer');
      if (serializer != null) {
        writer.writeln();
        writer.writeln('@override');
        writer.writeln('Serializer<${resultType.name}> get '
            'resultPayloadSerializer => ${resultType.name}.serializer;');
      }
    }
  }

  writer.writeln('}');

//  if (classType._routeActions || classType._outType != null) {
//    final String routeClassName = _appendName(classType.displayName, 'Route');
//    final String routeOptionsName = _appendName(routeClassName, 'Options');
//    writer.writeln();
//    writer.writeln('abstract class $routeClassName extends RouteDispatcher<'
//        '${classType.stateName}, ${classType.builderName}, ${classType._outType?.displayName ?? 'Null'}, ${classType.type.displayName}, $routeClassName> {');
//
//    writer.writeln('${_removeGenerics(routeClassName)}._();');
//    writer.writeln();
//    writer.writeln(
//        'factory ${_removeGenerics(routeClassName)}($routeOptionsName options) => _\$$routeClassName(options);');
//
//    writer.writeln('}');
//  }

  return writer.toString();
}

String _toFullType(String genericType) {
  if (genericType == null) return '';
  final buffer = StringBuffer('FullType(');
  for (var i = 0; i < genericType.length; i++) {
    final c = genericType[i];
    switch (c) {
      case '\t':
        break;
      case ' ':
        break;
      case '\r':
        break;
      case '\n':
        break;

      case '<':
        buffer.write(', [FullType(');
        break;

      case '>':
        buffer.write(')]');
        break;

      case ',':
        buffer.write('), FullType(');
        break;

      default:
        buffer.write(c);
        break;
    }
  }
  final b = buffer.toString();
  if (b.isEmpty) return '';
  if (b[b.length - 1] != ')') return b + ')';
  return b;
}

String _removeGenerics(String name) {
  final index = name.indexOf('<');
  return index > -1 ? name.substring(0, index) : name;
}

String _appendName(String name, String append) {
  final index = name.indexOf('<');
  if (index < 0) return '$name$append';
  return '${name.substring(0, index)}$append${name.substring(index)}';
}

MethodElement _superMethod(InterfaceType type, String methodName) {
  var method = type.getMethod(methodName);
  while (method == null && type != null) {
    type = type.superclass;
    method = type?.getMethod(methodName);
  }
  return method;
}

class SourceImport implements Comparable<SourceImport> {
  final String name;
  final String libraryName;
  final String importFile;

  final Set<String> serializers = Set();
  final Map<String, Map<String, SourceClass>> map = {};

  SourceImport(this.name, this.libraryName, this.importFile);

  String withPrefix(String name) {
    if (libraryName != null && libraryName.isNotEmpty)
      return '$libraryName.$name';
    return name;
  }

  void register(SourceClass cls) {
    if (cls == null) return;

    if (cls.serializable) {
      if (libraryName != null && libraryName.isNotEmpty) {
        serializers.add('$libraryName.${cls.type.name}.serializer');
      } else {
        serializers.add('${cls.type.name}.serializer');
      }
    }

    var m = map[cls.type.name];
    if (m == null) {
      m = <String, SourceClass>{};
      map[cls.type.name] = m;
    }

    m[cls.displayName] = cls;
  }

  @override
  int compareTo(SourceImport other) =>
      (importFile ?? '').compareTo(other?.importFile ?? '');
}

class Imports {
  final core = SourceImport('', '', '');
  final unknown = SourceImport('', '', '');
  final built_value = SourceImport('', '', '');
  final built_collection = SourceImport('', '', '');
  final map = <String, SourceImport>{};
  var count = 0;

  SourceImport getForType(DartType type) => get(type?.element);

  SourceImport get(Element element) {
    if (element == null) return unknown;
    final source = element.source;
    if (source == null) return unknown;

    if (source.fullName.startsWith('built_value')) {
      return built_value;
    }
    if (source.fullName.startsWith('built_collection')) {
      return built_collection;
    }
    var import = map[source.fullName];
    if (import == null) {
      final libraryName = '_${count++}';
      import = SourceImport(source.fullName, libraryName,
          'import \'package:${source.fullName.replaceFirst('|lib/', '/')}\' as $libraryName;');
      map[source.fullName] = import;
    }
    return import;
  }

  void dump() {
    final buffer = StringBuffer();
    map.values.forEach((import) {
      buffer.writeln('Import: ${import.name}');
      import.map.forEach((k, v) {
        buffer.writeln('\tKey: $k');
        v.forEach((k2, v2) {
          buffer.writeln('\t\t$k2 -> ${v2.displayName}');
          buffer.writeln('\t\t\t$k2 -> ${v2.builderName}');
        });
      });
    });

    print(buffer.toString());
  }
}

class SourceClass {
  final DartType type;
  final ClassElement element;
  final SourceImport import;
  final bool serializable;
  final List<SourceClass> typeArguments;
  final List<SourceClass> props;
  final String displayName;
  final String builderName;
  final String fullType;

  String get name => type?.name ?? '';

  bool get needsBuilder => typeArguments.isNotEmpty;

  SourceClass(
      this.type,
      this.element,
      this.import,
      this.serializable,
      this.typeArguments,
      this.props,
      this.displayName,
      this.builderName,
      this.fullType);

  static SourceClass create(DartType type, Imports imports) {
    if (type == null) return null;

    final el = type.element;
    if (el == null) return null;

    final lib = el.library;
    if (lib == null) return null;

    if (lib.isDartCore) {
      switch (type.name) {
        case 'bool':
          return SourceClass(
              type, type.element, imports.core, true, [], [], 'bool', '', '');
        case 'int':
          return SourceClass(
              type, type.element, imports.core, true, [], [], 'int', '', '');
        case 'num':
          return SourceClass(
              type, type.element, imports.core, true, [], [], 'num', '', '');

        case 'double':
          return SourceClass(
              type, type.element, imports.core, true, [], [], 'double', '', '');

        case 'String':
          return SourceClass(
              type, type.element, imports.core, true, [], [], 'String', '', '');

        case 'DateTime':
          return SourceClass(type, type.element, imports.core, true, [], [],
              'DateTime', '', '');

        case 'Duration':
          return SourceClass(type, type.element, imports.core, true, [], [],
              'Duration', '', '');

        case 'Uri':
          return SourceClass(
              type, type.element, imports.core, true, [], [], 'Uri', '', '');

        default:
          return null;
      }
    }

    if (type is InterfaceType) {
      final element = type.element;
      if (element == null) return null;

      final source = element.source;
      if (source == null) return null;

      final name = type.name;
      final overrideBuilderName = typesWithBuilder[name];

      final import = imports.get(element);
      if (import == null) return null;

      final args = type.typeArguments
          .map((t) => create(t, imports))
          .where((s) => s != null)
          .toList();

      final displayName = StringBuffer(import.withPrefix(name));
      final builderName = StringBuffer(import.withPrefix(
          overrideBuilderName != null
              ? '$overrideBuilderName'
              : '${name}Builder'));
      final fullType = StringBuffer('FullType(${import.withPrefix(name)}');
      if (args.isNotEmpty) {
        fullType.write(', [');
        displayName.write('<');
        builderName.write('<');

        bool first = true;
        for (final arg in args) {
          if (first) {
            first = false;
          } else {
            displayName.write(', ');
            builderName.write(', ');
            fullType.write(', ');
          }
          displayName.write(arg.displayName);
          builderName.write(arg.displayName);
          fullType.write(arg.fullType);
        }
        displayName.write('>');
        builderName.write('>');
        fullType.write('])');
      } else {
        fullType.write(')');
      }

      final serializable = type.accessors.firstWhere(
              (p) => p.isStatic && p.name == 'serializer',
              orElse: () => null) !=
          null;

      final props = typesWithBuilder[name] != null
          ? <SourceClass>[]
          : type.accessors
              .where((f) =>
                  !f.isStatic &&
                  f.returnType != null &&
                  f.returnType.element != null)
              .map((prop) => create(prop.returnType, imports))
              .where((s) => s != null)
              .toList();

      final cls = SourceClass(type, element, import, serializable, args, props,
          displayName.toString(), builderName.toString(), fullType.toString());

      import.register(cls);

      return cls;
    } else {}

    return null;
  }

  static bool isTemplate(DartType t) {
    if (t is InterfaceType &&
        t.typeParameters != null &&
        t.typeArguments != null) {
      if (t.typeParameters.length > t.typeArguments.length) return true;
      for (final arg in t.typeArguments) {
        if (arg.isDynamic ||
            isTemplate(arg) ||
            arg.element.kind == ElementKind.TYPE_PARAMETER) return true;
      }
    }
    return false;
  }
}

final typesWithBuilder = <String, String>{
  'BuiltList': 'ListBuilder',
  'BuiltListMultimap': 'ListMultimapBuilder',
  'BuiltMap': 'MapBuilder',
  'BuiltSet': 'SetBuilder',
  'BuiltSetMultimap': 'SetMultimapBuilder',
};
