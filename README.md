# flutter_gql_code_generator
Graph QL Code Generator for dart/flutter projects


## How To Use
# Setup
1- Recommanded, Optional:
add a sub package to manage the output of the generated code.
say for example: `project_gql_api`, in a sub folder named: `packages`

```
# inside the root folder of the project
mkdir packages && cd packages
flutter create --template=package ./project_gql_api
```

2- add to dev deps:
```
dev_dependencies:
  build_runner:
  flutter_gql_code_generator:
    git:
      url: https://github.com/weartio/flutter_gql_code_generator.git
      ref: v1.5
```
2.1- add configuration pubspec.yaml: e.g.:

```
flutter_gql_code_generator:
  - packageName: 'project_gql_api'
    packageDir: 'packages/project_gql_api'
    inputDir: 'lib/graphql'
    outputDir: 'lib/generated'
    isNullSafety: true
```
3- add a script file `run_code_generation.sh` to run code generation, added it to the root of the project path:

```
#!/bin/sh
set -x

# getting the script file directory path
path=`readlink -f "${BASH_SOURCE:-$0}"`
DIR_PATH=`dirname $path`


flutter pub run flutter_gql_code_generator

# formatting the generated files to bypass CI errors.
flutter format "${DIR_PATH}/packages/project_gql_api/lib/generated"
```
----------
Notes:
>1. make the file executable by runining:
>>```
>>chmod 777 run_code_generation.sh
>>```
>2. add to CI  

>>`- run: sh run_code_generation.sh`

>> after

>>`- run: flutter packages get`
----------

4- add the following code to `WebServiceConnections`, contact me for few modifications needed:
```
  Future<api.GraphQLResponse<TResult>?> runOperation<TResult>(
    api.BaseRequest<TResult> request,
    Storage storage, {
    bool throwIfHasErrors = true,
  }) async {
    final body = <String, dynamic>{
      'query': request.operation,
      'variables': request.inputs,
    };
    final result = await sendRequestToAPIWithHeader(
      storage.isLoggedIn ? AuthTypes.COGNITO : AuthTypes.API_KEY,
      CognitoConfig.appsyncGraphQLEndpoint!,
      body,
      returnRawResult: true,
    );
    final api.GraphQLResponse<TResult>? response =
        request.parseResponse(result);
    if (throwIfHasErrors) {
      response!.throwIfHasErrors();
    }
    return response;
  }
```
# Daily usage
5- for every query you want to generated add a `.gql` file contains the query code in the sub package `project_gql_api` in the sub directory `lib/graphql`.

6- run the code genration script file `run_code_generation.sh`.

7- in the data source of your feature import the the package as follows:
```
import 'package:project_gql_api/generated/exported.dart' as api;
```
8- use the following example as a template to run any operation:

```
  Future<api.CategoryListModel?> listCategories(
      api.PaginationInputModel input) async {
    final result = await _webServiceConnections.runOperation(
      api.ListCategoriesQuery(input: input),
      _storage,
    );
    return result?.data;
  }
```
