from django.contrib.auth.models import User, Group
from rest_framework import pagination, serializers


class UserSerializer(serializers.HyperlinkedModelSerializer):
    class Meta:  # pylint: disable=too-few-public-methods
        model = User
        fields = ['url', 'username', 'email', 'groups']


class GroupSerializer(serializers.HyperlinkedModelSerializer):
    class Meta:  # pylint: disable=too-few-public-methods
        model = Group
        fields = ['url', 'name']


class DefaultResultsSetPagination(pagination.PageNumberPagination):
    """
    Redefinition of PageNumberPagination for limit feature.
    """
    page_size_query_param = 'limit'
    max_page_size = 10000
