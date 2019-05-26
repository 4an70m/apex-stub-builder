public with sharing class StubBuilder {

    private final Type stubbedEntityType;
    private Map<String, List<Method>> methodsByName;

    public StubBuilder(Type stubbedEntityType) {
        this.stubbedEntityType = stubbedEntityType;
        this.methodsByName = new Map<String, List<Method>>();
    }

    //public methods
    public StubBuilder clearMethodMocks() {
        this.methodsByName = new Map<String, List<Method>>();
        return this;
    }

    public StubBuilder withStub(Method method) {
        if (!this.methodsByName.containsKey(method.getName())) {
            this.methodsByName.put(method.getName(), new List<Method>());
        }
        this.methodsByName.get(method.getName()).add(method);
        return this;
    }

    public StubBuilder preview() {
        System.debug(this.toString());
        return this;
    }

    public override String toString() {
        List<String> allMethods = new List<String>();
        for (List<Method> methods : this.methodsByName.values()) {
            for (Method method : methods) {
                allMethods.add('\t' + this.stubbedEntityType + method.toString());
            }
        }
        return '\nStub for ' + this.stubbedEntityType + ':\n' + String.join(allMethods, '\n') + '\n';
    }

    public Object getStubbedInstance() {
        return Test.createStub(this.stubbedEntityType, new MockProvider(this.stubbedEntityType, this.methodsByName));
    }


    //mock provider class
    public class MockProvider implements System.StubProvider {

        private final Type stubbedEntityType;
        private final Map<String, List<Method>> methodsByName;

        public MockProvider(Type stubbedEntityType, Map<String, List<Method>> methodsByName) {
            this.stubbedEntityType = stubbedEntityType;
            for (List<Method> methods : methodsByName.values()) {
                methods.sort();
            }
            this.methodsByName = methodsByName;
        }

        public Object handleMethodCall(Object stubbedObject, String stubbedMethodName,
                Type returnType, List<Type> listOfArgumentTypes, List<String> listOfParamNames,
                List<Object> listOfArgs) {
            List<Method> stubbedMethods = this.methodsByName.get(stubbedMethodName);
            if (stubbedMethods == null || stubbedMethods.isEmpty()) {
                System.debug('Method "' + stubbedMethodName + '" is not stubbed');
                return null;
            }

            List<Argument> arguments = this.convertToArguments(listOfArgumentTypes, listOfArgs);
            for (Method stubbedMethodCall : stubbedMethods) {
                if (stubbedMethodCall.matchMethodCallParams(arguments)) {
                    stubbedMethodCall.handleException();
                    return stubbedMethodCall.getReturnValue();
                }
            }
            System.debug('Method "' + stubbedMethodName + '" with arguments ' + arguments + ' is not stubbed');
            return null;
        }

        private List<Argument> convertToArguments(List<Type> listOfArgumentTypes, List<Object> listOfArgs) {
            final List<Argument> arguments = new List<Argument>();
            for (Integer i = 0; i < listOfArgumentTypes.size(); i++) {
                Type type = listOfArgumentTypes[i];
                Object value = listOfArgs[i];
                arguments.add(new Argument(type, value));
            }
            return arguments;
        }

        public override String toString() {
            List<String> allMethods = new List<String>();
            for (List<Method> methods : this.methodsByName.values()) {
                for (Method method : methods) {
                    allMethods.add('\t' + this.stubbedEntityType + method.toString());
                }
            }
            return '\nStub for ' + this.stubbedEntityType + ':\n' + String.join(allMethods, '\n') + '\n';
        }
    }

    //method class
    public class Method implements Comparable {

        private final String name;
        private final List<Argument> arguments;
        private Object returnValue;
        private Type expectedExceptionType;

        public Method(String methodName) {
            this.name = methodName;
            this.arguments = new List<Argument>();
        }

        public String getName() {
            return this.name;
        }

        public List<Argument> getArguments() {
            return this.arguments;
        }

        public Object getReturnValue() {
            return this.returnValue;
        }

        public Type getExpectedExceptionType() {
            return this.expectedExceptionType;
        }

        public Boolean matchMethodCallParams(List<Argument> callArguments) {
            if (this.getArguments().size() != callArguments.size()) {
                return false;
            }
            for (Integer i = 0; i < this.getArguments().size(); i++) {
                Argument thisMethodArgument = this.arguments[i];
                Argument callArgument = callArguments[i];

                if (!thisMethodArgument.equals(callArgument)) {
                    return false;
                }
            }
            return true;
        }

        public Method addArgument(Type argumentType) {
            return this.addArgument(new AnyValueArgument(argumentType));
        }

        public Method addArgument(Type argumentType, Object value) {
            return this.addArgument(new Argument(argumentType, value));
        }

        public Method addArgument(Argument argument) {
            this.arguments.add(argument);
            return this;
        }

        public Method addArguments(List<Type> argumentTypes) {
            for (Type argumentType : argumentTypes) {
                this.addArgument(new AnyValueArgument(argumentType));
            }
            return this;
        }

        public Method addArguments(List<Argument> arguments) {
            this.arguments.addAll(arguments);
            return this;
        }

        public Method addValue(Object value) {
            return this.addArgument(new AnyTypeArgument(value));
        }

        public Method addValues(List<Object> values) {
            for (Object value : values) {
                this.addValue(value);
            }
            return this;
        }

        public Method addAnyArgument() {
            return this.addArgument(new AnyArgument());
        }

        public Method addAnyArguments(Integer numberOfAnyArguments) {
            for (Integer i = 0; i < numberOfAnyArguments; i++) {
                this.addArgument(new AnyArgument());
            }
            return this;
        }

        public Method returnValue(Object returnValue) {
            this.returnValue = returnValue;
            return this;
        }

        public Method throwException(Type expectedExceptionType) {
            this.expectedExceptionType = expectedExceptionType;
            return this;
        }

        public Method preview() {
            System.debug(this.toString());
            return this;
        }

        public override String toString() {
            List<String> stringifiedArguments = new List<String>();
            for (Argument argument : this.arguments) {
                stringifiedArguments.add(argument.toString());
            }
            return '.' + this.getName() + '(' + String.join(stringifiedArguments, ', ') + ')'
                    + (
                        this.getExpectedExceptionType() == null ?
                        ' returning: "' + this.getReturnValue() + '"' :
                        ' throwing: "' + this.getExpectedExceptionType() + '"'
            );
        }

        public Integer compareTo(Object obj) {
            Method otherMethod = (Method) obj;
            Integer thisMethodParamSize = this.getArguments().size();
            Integer otherMethodParamSize = otherMethod.getArguments().size();

            if (thisMethodParamSize > otherMethodParamSize) {
                return -1;
            } else if (thisMethodParamSize < otherMethodParamSize) {
                return 1;
            }
            Integer thisMethodPriority = this.getMethodPriority();
            Integer otherMethodPriority = otherMethod.getMethodPriority();
            if (thisMethodPriority > otherMethodPriority) {
                return -1;
            }
            if (thisMethodPriority < otherMethodPriority) {
                return 1;
            }
            return 0;
        }

        private Integer getMethodPriority() {
            Integer priority = 0;
            for (Argument argument : this.getArguments()) {
                priority += argument.getArgumentPriority();
            }
            return priority;
        }

        private void handleException() {
            if (this.expectedExceptionType == null) {
                return;
            }
            Exception expectedException = (Exception) this.expectedExceptionType.newInstance();
            throw expectedException;
        }
    }


    //arguments class set
    public virtual class Argument {

        private final Type type;
        private final Object value;

        public Argument(Type type, Object value) {
            this.type = type;
            this.value = value;
        }

        public Type getType() {
            return type;
        }

        public Object getValue() {
            return value;
        }

        public virtual Integer getArgumentPriority() {
            return (this.getType() == AnyType.class ? 0 : 1) +
                   (this.getValue() instanceof AnyValue ? 0 : 2);
        }

        public override String toString() {
            return this.type.toString() + ' = ' + this.value;
        }

        private virtual Boolean equals(Argument argument) {
            return this.getType() == argument.getType()
                    && this.getValue() == argument.getValue();
        }
    }

    public class AnyTypeArgument extends Argument {

        private AnyTypeArgument(Object value) {
            super(AnyType.class, value);
        }

        private override Boolean equals(Argument argument) {
            return this.getValue() == argument.getValue();
        }
    }

    public class AnyValueArgument extends Argument {

        private AnyValueArgument(Type type) {
            super(type, new AnyValue());
        }

        private override Boolean equals(Argument argument) {
            return this.getType() == argument.getType();
        }
    }

    public class AnyArgument extends Argument {

        private AnyArgument() {
            super(AnyType.class, new AnyValue());
        }

        public override Integer getArgumentPriority() {
            return -1;
        }

        private override Boolean equals(Argument argument) {
            return true;
        }
    }


    //any type or value stub classes
    private class AnyType {

        public override String toString() {
            return 'AnyType.class';
        }
    }

    private class AnyValue {

        public override String toString() {
            return '<Any Value>';
        }
    }
}